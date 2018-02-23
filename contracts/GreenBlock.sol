pragma solidity 0.4.20;

/**
 * @title SafeMath
 * @dev Math operations with safety checks that throw on error
 */
library SafeMath {
  function mul(uint256 a, uint256 b) internal pure returns (uint256) {
    if (a == 0) {
      return 0;
    }
    uint256 c = a * b;
    assert(c / a == b);
    return c;
  }

  function div(uint256 a, uint256 b) internal pure returns (uint256) {
    // assert(b > 0); // Solidity automatically throws when dividing by 0
    uint256 c = a / b;
    // assert(a == b * c + a % b); // There is no case in which this doesn't hold
    return c;
  }

  function sub(uint256 a, uint256 b) internal pure returns (uint256) {
    assert(b <= a);
    return a - b;
  }

  function add(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a + b;
    assert(c >= a);
    return c;
  }
}
/**
 * @title Ownable
 * @dev The Ownable contract has an owner address, and provides basic authorization control
 * functions, this simplifies the implementation of "user permissions".
 */
contract Ownable {
  address public owner;


  event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);


  /**
   * @dev The Ownable constructor sets the original `owner` of the contract to the sender
   * account.
   */
  function Ownable() public {
    owner = msg.sender;
  }

  /**
   * @dev Throws if called by any account other than the owner.
   */
  modifier onlyOwner() {
    require(msg.sender == owner);
    _;
  }

  /**
   * @dev Allows the current owner to transfer control of the contract to a newOwner.
   * @param newOwner The address to transfer ownership to.
   */
  function transferOwnership(address newOwner) public onlyOwner {
    require(newOwner != address(0));
    OwnershipTransferred(owner, newOwner);
    owner = newOwner;
  }

}

contract GreenBlock is Ownable{
    
    using SafeMath for uint256;

    //wallet address which will receive the funds
    address walletAddress;

    //list of moderators
    mapping(address=>bool) allowedModerator;

    uint totalTreesPlanted;

    uint totalTreesToBePlanted;

    struct Request{
        address who;
        uint priceInWei;
        uint8 amount;
    }

   
    //keeps track of user requests in above mapping
    mapping(address=>uint8[])userVsRequestIndexes;

    //contains all requests
    Request[] allRequests;

    struct PlantedTrees{
        address donor;
        bytes32 name;
        bytes32 location;
        bytes32 description;
        bytes32 lifespan;
        bytes32 linkToImage;
    }
    

    mapping(address=>PlantedTrees[]) userVsPlantedTrees;

    //event to log new request
    event TreeRequested(address indexed requestor, uint8 noOfTrees);

    //event to log request completion/ tree planted
    event TreePlanted(address indexed requestor);

    //event to log addition of new moderator
    event ModeratorAdded(address indexed moderator);

    //event to log removal of moderator
    event ModeratorRemoved(address indexed moderator);
  
    modifier onlyModerator(){
        require(allowedModerator[msg.sender]==true);
        _;
    }

    //don't allow someone to mistakenly send money to the contract
    function()payable public{
        revert();
    }

    function getTotalTreesPlanted()public view returns(uint){
        return totalTreesPlanted;
    }

    function getTotalTreesToBePlanted()public view returns(uint){
        return totalTreesToBePlanted;
    }

    //add new moderators
    function addModerator(address moderator)onlyOwner public{
        allowedModerator[moderator]=true;
    }

    //remove some existing moderator
    function removeModerator(address moderator)onlyOwner public{
        allowedModerator[moderator]=false;
    }

    //Withdraw money to the wallet
    function withdraw()onlyOwner public{
        walletAddress.transfer(this.balance);
    }


    function changeWalletAddress(address newWalletAddress)onlyOwner public{
        walletAddress=newWalletAddress;
    }

    function plantTrees(uint priceInWeiPerTree, uint8 noOfTrees)payable public{
        require(priceInWeiPerTree>=0.01 ether && noOfTrees>0);
        require(totalTreesToBePlanted.add(noOfTrees)<=10000);
        require(userVsRequestIndexes[msg.sender].length.add(noOfTrees) <= 10);

        uint totalCost = priceInWeiPerTree.mul(noOfTrees);

        require(msg.value>=totalCost);

        totalTreesToBePlanted = totalTreesToBePlanted.add(noOfTrees);

       
        Request memory request = Request({
            who:msg.sender,
            priceInWei:priceInWeiPerTree,
            amount:noOfTrees
        });
        
        allRequests.push(request);
        
        userVsRequestIndexes[msg.sender].push(uint8(allRequests.length.sub(1)));
        
        TreeRequested(msg.sender, noOfTrees);
    }

    function treesPlantedByAddress(address contributor)public constant returns (bytes32[], bytes32[], bytes32[], bytes32[], bytes32[]){
        bytes32[] memory names = new bytes32[](userVsPlantedTrees[contributor].length);
        bytes32[] memory locations = new bytes32[](userVsPlantedTrees[contributor].length);
        bytes32[] memory descriptions = new bytes32[](userVsPlantedTrees[contributor].length);
        bytes32[] memory lifeSpans = new bytes32[](userVsPlantedTrees[contributor].length);
        bytes32[] memory imageLinks = new bytes32[](userVsPlantedTrees[contributor].length);
        for(uint i=0;i<userVsPlantedTrees[contributor].length;i++){
            names[i]=userVsPlantedTrees[contributor][i].name;
            locations[i]=userVsPlantedTrees[contributor][i].location;
            descriptions[i]=userVsPlantedTrees[contributor][i].description;
            lifeSpans[i]=userVsPlantedTrees[contributor][i].lifespan;
            imageLinks[i]=userVsPlantedTrees[contributor][i].linkToImage;
        }
        return (names,locations,descriptions,lifeSpans,imageLinks);
    }

    function pendingTreeRequestForAddress(address contributor)public view returns(uint[], uint8[]){
        uint[] memory prices = new uint[](userVsRequestIndexes[contributor].length);
        uint8[] memory amount = new uint8[](userVsRequestIndexes[contributor].length);

        for(uint8 i = 0; i<userVsRequestIndexes[contributor].length; i++){
            prices[i]=allRequests[userVsRequestIndexes[contributor][i]].priceInWei;
            amount[i]=allRequests[userVsRequestIndexes[contributor][i]].amount;
        }
        return (prices, amount);
    }

    function getAllPendingRequests()onlyModerator view public returns(address[], uint[], uint8[], uint8[]){
        address[] memory whos = new address[](allRequests.length);
        uint[] memory prices = new uint[](allRequests.length);
        uint8[]memory amounts = new uint8[](allRequests.length);
        uint8[]memory indexes = new uint8[](allRequests.length);
        for(uint8 i=0;i<allRequests.length;i++){
            whos[i]=allRequests[i].who;
            prices[i]=allRequests[i].priceInWei;
            amounts[i]=allRequests[i].amount;
            indexes[i]=i;
        }
        return (whos, prices, amounts, indexes);
    }

    function serveRequest(address contributor, uint8 index, bytes32 treeName, bytes32 treeLocation, bytes32 description, bytes32 lifeSpan, bytes32 imageLink)onlyModerator public {
        
        require(treeName.length>0 && treeLocation.length>0 && description.length>0 && lifeSpan.length>0 && imageLink.length>0);
        
        require(allRequests.length>index);
        
        require(contributor != 0x0);
        
        require(allRequests[index].amount>0);
        
        require(allRequests[index].who == contributor);
        
        Request storage request = allRequests[index];
        
        request.amount-=1;
        
        //remove request from the array if amount is 0
        if(request.amount==0) {
            
            if(allRequests.length>1){
                for(uint8 i=0; i<userVsRequestIndexes[allRequests[allRequests.length-1].who].length;i++){
                    
                    if(userVsRequestIndexes[allRequests[allRequests.length-1].who][i] == allRequests.length-1){
                        userVsRequestIndexes[allRequests[allRequests.length-1].who][i] = index;
                        break;
                    }

                }
                allRequests[index] = allRequests[allRequests.length-1];
                
            }
            for(uint8 j=0;j<userVsRequestIndexes[contributor].length;j++){
                if(userVsRequestIndexes[contributor][i] == index){
                        userVsRequestIndexes[contributor][i] = userVsRequestIndexes[contributor][userVsRequestIndexes[contributor].length-1];
                        delete userVsRequestIndexes[contributor][userVsRequestIndexes[contributor].length-1];
                        userVsRequestIndexes[contributor].length--;
                        break;
                    }
            }
                delete allRequests[allRequests.length-1];
                allRequests.length--;
            
        }
        
        PlantedTrees memory tree;
        tree.name = treeName;
        tree.location=treeLocation;
        tree.description=description;
        tree.lifespan=lifeSpan;
        tree.linkToImage=imageLink;
        
        userVsPlantedTrees[contributor].push(tree);
        totalTreesPlanted = totalTreesPlanted.add(1);
        TreePlanted(contributor);

    }
    function GreenBlock(address _walletAddress)public{
        walletAddress = _walletAddress;
        allowedModerator[owner]=true;
    }

}