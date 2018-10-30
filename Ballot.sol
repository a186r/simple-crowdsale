pragma solidity ^0.4.25;

contract Ballot{

    // 一个选民的结构体
    struct Voter{
        uint weight; //权重是通过委托积累的
        bool voted; //如果是true，说明他已经投票过了
        address delegate; //委派给xxx
        uint vote;//投票提案的索引
    }

    // 单个投票提案的结构体
    struct Proposal{
        bytes32 name;
        uint voteCount;
    }

    address public chairperson;

    // 为每一个地址声明一个Voter结构
    mapping(address => Voter) public voters;

    // 一个存储提案的变长数组
    Proposal[] public paoposals;

    // 使用proposalName创建新的投票
    constructor(bytes32[] proposalNames) public {
        chairperson = msg.sender;
        voters[chairperson].weight = 1;

        // 创建一个新的Proposal对象并且添加到proposals末尾
        for(uint i = 0;i < proposalNames.length;i++){
            proposals.push(Proposal({
                name: proposalNames[i],
                voteCount: 0
            }));
        }
    }

    // 赋予选民投票权，只能由chairperson调用
    function giveRightToVote(address voter) public {
        // 如果满足条件则直接执行下面的代码，否则打印出后面的错误信息
        // 只能由chairperson调用
        require(msg.sender == chairperson,"only chairperson can give right to vote.");
        
        // 这个地址还没有投票
        require(!voter[voter].voted,"The voter already voted.");

        // 权重是0，然后将权重赋值为1
        require(voters[voter].weight == 0);
        voters[voter].weight = 1;
    }

    // 将自己的选票委托给其他选民
    function delegate(address to) public {
        // 引用
        Voter storage sender = voters[msg.sender];

        require(!sender.voted,"You already voted.");

        require(to != msg.sender,"Self-delegation is disallowed");

        // 委托转发，一般来说，这样的循环非常危险，可能会消耗非常多的gas
        while(voters[to].delegate != address(0)){
            to = voters[to].delegate;

            require(to != msg.sender,"Found loop in delegation.");
        }

        // 由于sender是一个引用，这里修改voters[msg.sender].voted.
        sender.voted = true;
        sender.delegate = to;
        Voter storage delegate_ = voters[to];
        if(delegate_.voted){
            proposals[delegate_.vote].voteCount += sender.weight;
        }else{
            delegate_.weight += sender.weight
        }
    }

    // 投票，包括委托给你的投票
    function vote(uint proposal) public {
        Voter storage sender = voters[msg.sender];
        require(!sender.voted,"Already voted.");

        sender.voted = true;
        sender.vote = proposal;

        proposals[proposal].voteCount += sender.weight;
    }

    // 计算获胜的提案
    function winningProposal() public view returns (uint winningProposal_){
        uint winningVoteCount = 0;
        for(uint p = 0;p< proposals.length;p++){
            if(proposals[p].voteCount > winningVoteCount){
                winningVoteCount = proposals[p].voteCount;
                winningProposal_ = p;
            }
        }
    }

    // 返回获胜的提案名称
    function winnerName() public view returns (bytes32 winnerName_){
        winnerName_ = proposals[winningProposal().name];
    }
}