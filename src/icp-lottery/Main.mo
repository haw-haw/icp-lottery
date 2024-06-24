import Timer "mo:base/Timer";
import Random "mo:stdlib/Random";
import Principal "mo:base/Principal";
import Nat "mo:base/Nat";
import Array "mo:base/Array";
import ICRC1 "ic:icrc1";  // 引入 ICRC1 接口

actor ICP_Lottery {

    // 定义用户结构
    type User = {
        id: Nat;
        address: Principal;
        amount: Nat;
    };

    // 记录参与者和奖池
    var users: [User] = [];
    var prizePool: Nat = 0;
    var managementWallet: Principal = Principal.fromActor("w7x7r-cok77-xa");
    var managementFeePercentage: Float = 0.1;  // 10%的管理费用
    var lotteryInterval: Nat = 24 * 60 * 60 * 1000; // 默认24小时，以毫秒为单位
    var cyclesCost: Nat = 10_000;  // 假设每次转账的周期成本
    var isGameActive: Bool = false; // 游戏是否正在进行
    let admin: Principal = Principal.fromActor("aaaaa-aa"); // 管理员地址，需要替换为实际值
    
    // 代币地址
    let ICRC1Token: Principal = Principal.fromActor("YOUR_TOKEN_CANISTER_ID"); // 替换为实际的代币 Canister ID

    // 初始化定时器
    Timer.setInterval<Nat>(lotteryInterval, func() {
        ignore (endDepositAndDrawLottery(0.5));
    });

    // 管理员权限检查
    private func isAdmin(caller: Principal): Bool {
        return caller == admin;
    }

    // 定义转账函数
    public shared(msg) func deposit() : async Bool {
        if (!isGameActive) {
            return false;
        }

        let caller: Principal = msg.caller;
        let amount: Nat = 10000;  // 示例金额为 10000，实际情况调整为0.0001 ICP 等于的单位

        // 调用 ICRC-1 接口来转账
        let tokenTransferResult = await ICRC1Transfer({
            from = caller;
            to = Principal.self; // 转到合约地址
            amount = Nat64.fromNat(amount)
        });

        switch(tokenTransferResult) {
            case (#ok):
                // 创建用户并追加到用户列表
                users := Array.append<User>(users, [{id = users.size(); address = caller; amount = amount}]);

                // 增加奖池总额
                prizePool += amount;

                return true;
            case (#error(_)): return false;
        }
    };

    // 重新开始新一轮
    public shared(msg) func startNewRound() : async Bool {
        if (!isAdmin(msg.caller)) {
            return false;
        }

        if (isGameActive) {
            return false;
        }

        // 重置所有状态
        users := [];
        prizePool := 0;
        isGameActive := true;

        return true;
    }

    // 结束存币并抽奖
    public shared func endDepositAndDrawLottery(winningRate: Float) : async [User] {
        if (!isGameActive) {
            return [];
        }

        // 抽取管理费用
        let managementFee = Float.toNat(Float.ofNat(prizePool) * managementFeePercentage);
        let feeAfterCycles = managementFee.saturatingSub(cyclesCost);  // 扣掉周期成本
        let remainingPool = prizePool - managementFee;

        let numberOfWinners = Float.ceil(Float.ofNat(users.size()) * winningRate);
        var winners: [User] = [];

        if (numberOfWinners > 0) {
            let winningIds = sample(users.size(), numberOfWinners);
            let prizePerWinner = remainingPool / numberOfWinners;
            let prizeAfterCycles = prizePerWinner.saturatingSub(cyclesCost);  // 扣掉周期成本

            for (winningId in winningIds.vals()) {
                let winner = Array.find<User>(users, func(user) { user.id == winningId });
                switch (winner) {
                    case (#some(user)):
                        winners := Array.append<User>(winners, [{ id = user.id; address = user.address; amount = prizeAfterCycles }]);
                        await distributePrize(user.address, prizeAfterCycles);
                    case (#none):
                }
            }
        }

        // 转账管理费用到管理钱包
        await distributePrize(managementWallet, feeAfterCycles);

        // 重置奖池
        prizePool := 0;
        // 清空用户列表
        users := [];

        // 设置游戏状态为结束
        isGameActive := false;

        // 返回中奖者信息
        return winners;
    };

    // 分发奖金和管理费用
    private func distributePrize(address: Principal, amount: Nat): async Bool {
        let tokenTransferResult = await ICRC1.transfer({
            from = Principal.self,
            to = address,
            amount = Nat64.fromNat(amount)
        });

        switch(tokenTransferResult) {
            case (#ok): return true;
            case (#error(_)): return false;
        }
    };

    // 自定义随机抽样函数
    private func sample(total: Nat, count: Nat) : [Nat] {
        var indices = Array.tabulate<Nat>(total, func(i) { i });
        var winningIndices: [Nat] = [];

        var rng = Random.new();
        for (var i = 0; i < count; i += 1) {
            let randomIndex = rng.nextInt(indices.size());
            winningIndices := Array.append<Nat>(winningIndices, [indices[randomIndex]]);
            indices := Array.removeAt<Nat>(indices, randomIndex);
        }
        return winningIndices;
    }

    // 设置管理费用费率
    public shared(msg) func setManagementFeePercentage(newPercentage: Float): async Bool {
        if (!isAdmin(msg.caller)) {
            return false;
        }

        if (!isGameActive) {
            return false;
        }

        managementFeePercentage := newPercentage;
        return true;
    }

    // 设置自动结束时间
    public shared(msg) func setLotteryInterval(newInterval: Nat): async Bool {
        if (!isAdmin(msg.caller)) {
            return false;
        }

        if (isGameActive) {
            return false;
        }

        lotteryInterval := newInterval;

        // 重新设置定时器
        Timer.clearInterval();
        Timer.setInterval<Nat>(lotteryInterval, func() {
            ignore (endDepositAndDrawLottery(0.5));
        });

        return true;
    }

    // 从合约地址转出余额
    public shared(msg) func withdrawFunds(to: Principal, amount: Nat): async Bool {
        if (!isAdmin(msg.caller)) {
            return false;
        }

        if (isGameActive) {
            return false;
        }

        let currentBalance = await ICRC1Balance();

        if (currentBalance >= amount + cyclesCost) {
            let amountAfterCycles = amount.saturatingSub(cyclesCost);
            return await distributePrize(to, amountAfterCycles);
        } else {
            return false;
        }
    }

    // 列出当前参与的用户信息
    public shared(msg) func listUsers(): async [User] {
        if (!isAdmin(msg.caller)) {
            return [];
        }
        return users;
    }

    // 模拟 ICRC-1 接口中的transfer方法
    private func ICRC1Transfer(arg: {
        from: Principal;
        to: Principal;
        amount: Nat64;
    }) : async {
        try {
            let icrc1 = actor ICRC1Token : ICRC1.ICRC1;
            await icrc1.transfer(arg);
            return #ok;
        } catch (err) {
            return #error(err);
        }
    }

    // 模拟 ICRC-1 接口中的balance查询方法
    private func ICRC1Balance() : async Nat {
        let icrc1 = actor ICRC1Token : ICRC1.ICRC1;
        let balanceResult = await icrc1.balanceOf({ owner = Principal.self });
        return balanceResult;
    }

    public shared(msg) func getWinnersList(): async [User] {
        if (msg.caller != admin) {
            return []; // 如果调用者不是管理员，返回空
        }

        if (isGameActive) {
            return []; // 如果游戏仍在进行中，返回空
        }

        // 游戏已结束，返回中奖者信息
        return await endDepositAndDrawLottery(0.5);
    }
};
