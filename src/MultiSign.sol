// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

// 状态。
enum TxState {
    Confirming, // 确认中
    Executed, // 已经执行
    Canceled, // 取消
    None // 未使用
}

// struct 可以放外面。
struct Transaction {
    uint txId; // ID
    address creator; // 创建者。
    // string storage title; // 标题。 错误。struct 不能用位置。
    string title; // 标题。
    address to; // 转给谁
    uint goal; // 金额。
    // address[] ownerList; // 多个所有者。 list 。 第一个不使用，用0表示不存在。
    // mapping(address => uint) ownerIndexMap; // 每个人的下标。 key=user value=index
    mapping(address => bool) ownerConfirmed; // 哪些人确认了。 key=user
    // uint needConfirm; // 需要多少个人确认。
    uint countConfirmed; // 已经有多少个人确认。
    TxState state; // 状态。
}

// 多签钱包。
contract MultiSignContract {
    uint txIdSeq = 1; // 交易的序号。
    mapping(uint => Transaction) txIdMap; // 交易的map 。 key=txId

    // owner放外面。 所有交易共用。
    address[] ownerList; // 多个所有者。 list 。
    mapping(address => uint) ownerIndexMap; // 每个人的下标。 key=user value=index
    mapping(address => bool) ownerBeMap; // 某个人是否owner。
    uint needConfirm; // 需要多少个人确认。

    event RecvMoney(address from, uint amount);
    event TxCreated(
        address indexed creator,
        uint indexed txId,
        string title,
        address indexed to,
        uint goal
    );
    event TxConfirmOnce(uint indexed txId, address indexed user);
    event TxConfirmRevoked(uint indexed txId, address indexed user);
    event TxExecuted(
        uint indexed txId,
        address indexed user,
        address indexed to,
        uint goal
    );
    event TxCanceled(uint indexed txId, address indexed user);
    event OwnerAdded(address indexed user);
    event OwnerRemoved(address indexed user);

    // 传入全局参数。
    constructor(address[] memory ownerList2, uint needConfirm2) {
        needConfirm = needConfirm2;
        // 填list
        ownerList.push(msg.sender);
        for (uint k = 0; k < ownerList2.length; k++) {
            ownerList.push(ownerList2[k]);
        }
        // 把列表写入map
        uint len = ownerList.length;
        for (uint k = 0; k < len; k++) {
            address user = ownerList[k];
            // 重复了。
            if (ownerBeMap[user]) {
                revert(">>>  owner repeat");
            }
            ownerBeMap[user] = true; // 存在
            ownerIndexMap[user] = k; // 下标
            emit OwnerAdded(user);
        }
    }

    // 别人把钱转入这个钱包。
    receive() external payable {
        emit RecvMoney(msg.sender, msg.value);
    }

    // 创建交易。
    function createTx(
        string memory title,
        address to,
        uint goal
    ) public returns (uint txId) {
        // 验证参数
        require(msg.sender != address(0), "caller invalid");
        require(to != address(0), "to invalid");
        require(goal > 0, "goal invalid");
        require(ownerList.length > 0, "ownerList invalid");
        require(needConfirm > 0, "needConfirm invalid");

        // Transaction memory tx = new Transaction(); // 错误。struct 不能用 new

        // 错误。Struct containing a (nested) mapping cannot be constructed.
        // Transaction storage tx = Transaction({
        //     title: title,
        // });

        // Transaction storage tx; // 错误。存储指针 tx 没有指向任何实际的存储位置。

        uint newTxId = txIdSeq; // ID
        txIdSeq++;

        // 正确。
        Transaction storage txx = txIdMap[newTxId]; // 从storage中，取一个storage地址。
        txx.txId = newTxId;
        txx.creator = msg.sender;
        txx.title = title;
        txx.to = to;
        txx.goal = goal;
        txx.state = TxState.Confirming;

        // 事件。
        emit TxCreated(txx.creator, txx.txId, txx.title, txx.to, txx.goal);
        return (newTxId);
    }

    // owner才能操作。
    modifier needOwner() {
        require(ownerBeMap[msg.sender], "user not owner");
        _;
    }

    // 状态
    modifier inState(uint txId, TxState state) {
        _inState(txId, state);
        _;
    }
    // 要求减少代码。
    function _inState(uint txId, TxState state) private view {
        // 引用。
        Transaction storage txx = txIdMap[txId];
        require(txx.creator != address(0), "Transaction not exist");
        require(txx.state == state, "state not match");
    }

    // 查询tx。
    function queryTx(
        uint txId
    )
        public
        view
        needOwner
        returns (
            uint txId_,
            address creator,
            address to,
            uint goal,
            string memory title,
            uint ownerCount,
            uint needConfirm_,
            TxState state
        )
    {
        // 引用。
        Transaction storage txx = txIdMap[txId];
        return (
            txx.txId,
            txx.creator,
            txx.to,
            txx.goal,
            txx.title,
            ownerList.length,
            needConfirm,
            txx.state
        );
    }

    function queryOwnerList() public returns (address[] memory) {
        return ownerList; // 直接把 storage 复制为 memory
    }

    // 添加owner。
    function ownerAddOne(
        address ownerAdd
    ) public needOwner returns (uint ownerCount, string memory desc) {
        require(ownerAdd != address(0), "ownerAdd invalid ");
        // 已经在owner里。不操作。
        if (ownerBeMap[ownerAdd]) {
            return (ownerList.length, "owner already in , no op");
        }

        // 添加。
        ownerList.push(ownerAdd); // 列表
        ownerIndexMap[ownerAdd] = ownerList.length - 1; // 下标
        ownerBeMap[ownerAdd] = true; // 存在

        emit OwnerAdded(ownerAdd);
        return (ownerList.length, "put owner OK");
    }

    // 移除owner。
    function ownerRemoveOne(
        address ownerRemove
    ) public needOwner returns (uint ownerCount) {
        require(ownerRemove != address(0), "ownerRemove invalid ");

        // 不在列表。忽略。
        if (!ownerBeMap[ownerRemove]) {
            return (ownerList.length);
        }

        // 交换末尾元素。
        uint index = ownerIndexMap[ownerRemove]; // 当前下标
        uint lastIndex = ownerList.length - 1; // 末尾下标
        address lastOwner = ownerList[lastIndex]; // 末尾元素
        ownerList[lastIndex] = ownerRemove; // 列表，交换元素
        ownerList[index] = lastOwner; // 列表，交换元素
        ownerIndexMap[ownerRemove] = lastIndex; // map，交换下标
        ownerIndexMap[lastOwner] = index; // map，交换下标

        // 删除这个元素。
        delete ownerIndexMap[ownerRemove]; // 删除map元素
        delete ownerBeMap[ownerRemove]; // 删除map元素
        ownerList.pop(); // 删除list元素

        // 如果有确认，还需要取消确认。
        // 已经确认过。
        // if (txx.ownerConfirmed[ownerRemove]) {
        //     delete txx.ownerConfirmed[ownerRemove];
        //     txx.countConfirmed--; // 计数。
        //     emit TxConfirmRevoked(txId, ownerRemove); // 事件。
        // }

        emit OwnerRemoved(ownerRemove);

        return (ownerList.length);
    }

    // 确认一次。
    function confirmOnce(
        uint txId
    )
        public
        needOwner
        inState(txId, TxState.Confirming)
        returns (uint countConfirmed)
    {
        // 引用。
        Transaction storage txx = txIdMap[txId];
        // 已经确认过。
        if (txx.ownerConfirmed[msg.sender]) {
            // 不操作。
        } else {
            txx.ownerConfirmed[msg.sender] = true;
            txx.countConfirmed++; // 计数。
            emit TxConfirmOnce(txId, msg.sender); // 事件。
        }
        return (txx.countConfirmed);
    }

    // 确认取消。
    function confirmRevoke(
        uint txId
    )
        public
        needOwner
        inState(txId, TxState.Confirming)
        returns (uint countConfirmed)
    {
        // 引用。
        Transaction storage txx = txIdMap[txId];
        // 已经确认过。
        if (txx.ownerConfirmed[msg.sender]) {
            delete txx.ownerConfirmed[msg.sender];
            txx.countConfirmed--; // 计数。
            emit TxConfirmRevoked(txId, msg.sender); // 事件。
        } else {
            // 不操作。
        }
        return (txx.countConfirmed);
    }

    // 执行。
    function executeTx(
        uint txId
    )
        public
        needOwner
        inState(txId, TxState.Confirming)
        returns (bool ok, string memory desc)
    {
        // 引用。
        Transaction storage txx = txIdMap[txId];
        // 数量还不够。
        if (txx.countConfirmed < needConfirm) {
            return (false, "count invalid");
        }

        require(address(this).balance > txx.goal, "balance not enough");

        // 数量够了。
        // 改状态。
        txx.state = TxState.Executed;
        // 把钱转出。
        (bool success, ) = payable(txx.to).call{value: txx.goal}("");
        require(success, "transfer error");

        // 事件。
        emit TxExecuted(txId, msg.sender, txx.to, txx.goal);
        return (true, "OK");
    }

    // 取消。
    function cancelTx(
        uint txId
    ) public needOwner inState(txId, TxState.Confirming) {
        // 引用。
        Transaction storage txx = txIdMap[txId];
        txx.state = TxState.Canceled;
        emit TxCanceled(txId, msg.sender);
    }
}
