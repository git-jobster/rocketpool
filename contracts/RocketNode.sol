pragma solidity 0.4.19;


import "./RocketBase.sol";
import "./RocketPoolMini.sol"; 
import "./interface/RocketStorageInterface.sol";
import "./interface/RocketSettingsInterface.sol";
import "./interface/RocketPoolInterface.sol";


/// @title The Rocket Smart Node contract
/// @author David Rugendyke
contract RocketNode is RocketBase {
                          

    /*** Contracts **************/

    RocketSettingsInterface rocketSettings = RocketSettingsInterface(0);  // The main settings contract most global parameters are maintained 

              
    /*** Events ****************/

    event NodeRegistered (
        address indexed _nodeAddress,
        uint256 created
    );

    event NodeRemoved (
        address indexed _address,
        uint256 created
    );

    event NodeCheckin (
        address indexed _nodeAddress,
        uint256 loadAverage,
        uint256 created
    );

    event NodeActiveStatus (
        address indexed _nodeAddress,
        bool indexed _active,
        uint256 created
    );


       

    /*** Modifiers *************/


    /// @dev Only allow access from the latest version of the RocketPool contract
    modifier onlyLatestRocketPool() {
        require(msg.sender == rocketStorage.getAddress(keccak256("contract.name", "rocketPool")));
        _;
    }

    /// @dev Only registered pool node addresses can access
    /// @param _nodeAccountAddress node account address.
    modifier onlyRegisteredNode(address _nodeAccountAddress) {
        require(rocketStorage.getBool(keccak256("node.exists", _nodeAccountAddress)));
        _;
    }


    
    /*** Methods *************/
   
    /// @dev pool constructor
    function RocketNode(address _rocketStorageAddress) RocketBase(_rocketStorageAddress) public {
        // Version
        version = 1;
    }

    /*** Getters *************/

    /// @dev Returns the amount of registered rocket nodes
    function getNodeCount() public view returns(uint) {
        return rocketStorage.getUint(keccak256("nodes.total"));
    }

    /// @dev Returns true if this node exists, reverts if it doesn't
    /// @param _nodeAddress node account address.
    function getNodeExists(address _nodeAddress) public view onlyRegisteredNode(_nodeAddress) returns(bool) {
        return true; 
    }

    
    /// @dev Get an available node for a pool to be assigned too, is requested by the main Rocket Pool contract
    // TODO: As well as assigning pools by node user server load, assign by node geographic region to aid in redundancy and decentralisation 
    function getNodeAvailableForPool() external view onlyLatestRocketPool returns(address) {
        // Create an array at the length of the current nodes, then populate it
        address[] memory nodes = new address[](rocketStorage.getUint(keccak256("nodes.total")));
        address nodeAddressToUse = 0x0;
        uint256 prevAverageLoad = 0;
        // Retreive each node address now by index since we are using a key/value datastore
        require(nodes.length > 0);
        // Now loop through each, requires uint256 so that the hash matches the index correctly
        for (uint256 i = 0; i < nodes.length; i++) {
            // Get our node address
            address currentNodeAddress = rocketStorage.getAddress(keccak256("nodes.index.reverse", i));
            // Get the node details
            uint256 averageLoad = rocketStorage.getUint(keccak256("node.averageLoad", currentNodeAddress));
            // Get the node with the lowest current work load average to help load balancing and avoid assigning to any servers currently not activated
            // A node must also have checked in at least once before being assinged, hence why the averageLoad must be greater than zero
            nodeAddressToUse = (averageLoad <= prevAverageLoad || i == 0) && averageLoad > 0 && rocketStorage.getBool(keccak256("node.active", currentNodeAddress)) == true ? currentNodeAddress : nodeAddressToUse;
            prevAverageLoad = averageLoad;
        }
        // We have an address to use, excellent, assign it
        if (nodeAddressToUse != 0x0) {
            return nodeAddressToUse;
        }
    } 

    /*** Setters *************/


    /// @dev Owner can manually activate or deactivate a node, this will stop the node accepting new pools to be assigned to it
    /// @param _nodeAddress Address of the node
    /// @param _activeStatus The status to set the node
    function setNodeActiveStatus(address _nodeAddress, bool _activeStatus) public onlyRegisteredNode(_nodeAddress) onlyOwner {
        // Get our RocketHub contract with the node storage, so we can check the node is legit
        rocketStorage.setBool(keccak256("node.active", _nodeAddress), _activeStatus);
    }

    /// @dev Owner can change a nodes oracle ID ('aws', 'rackspace' etc)
    /// @param _nodeAddress Address of the node
    /// @param _providerID The oracle ID
    function setNodeproviderID(address _nodeAddress, string _providerID) public onlyRegisteredNode(_nodeAddress) onlyOwner {
        // Get our RocketHub contract with the node storage, so we can check the node is legit
        rocketStorage.setString(keccak256("node.providerID", _nodeAddress), _providerID);
    }

    /// @dev Owner can change a nodes instance ID ('aws', 'rackspace' etc)
    /// @param _nodeAddress Address of the node
    /// @param _instanceID The instance ID
    function setNodeInstanceID(address _nodeAddress, string _instanceID) public onlyRegisteredNode(_nodeAddress) onlyOwner {
        // Get our RocketHub contract with the node storage, so we can check the node is legit
        rocketStorage.setString(keccak256("node.instanceID", _nodeAddress), _instanceID);
    }

    /*** Methods ************/

    /// @dev Register a new node address if it doesn't exist, only the contract creator can do this
    /// @param _newNodeAddress New nodes coinbase address
    /// @param _providerID Current provider identifier for this node (eg AWS, Rackspace etc)
    /// @param _subnetID Current subnet identifier for this node (eg NViginia, Ohio etc)
    /// @param _instanceID The instance ID of the server (eg FA3422)
    /// @param _regionID The region ID of the server (aus-east, america-north etc)
    function nodeAdd(address _newNodeAddress, string _providerID, string _subnetID, string _instanceID, string _regionID) public onlyOwner returns (bool) {
        // Get our settings
        rocketSettings = RocketSettingsInterface(rocketStorage.getAddress(keccak256("contract.name", "rocketSettings")));
        // Check the address is ok
        require(_newNodeAddress != 0x0);
        // Get the balance of the node, must meet the min requirements to service gas costs for checkins, oracle services etc
        require(_newNodeAddress.balance >= rocketSettings.getSmartNodeEtherMin());
        // Check it doesn't already exist
        require(!rocketStorage.getBool(keccak256("node.exists", _newNodeAddress)));
        // Get how many nodes we currently have  
        uint256 nodeCountTotal = rocketStorage.getUint(keccak256("nodes.total")); 
        // Ok now set our node data to key/value pair storage
        rocketStorage.setString(keccak256("node.providerID", _newNodeAddress), _providerID);
        rocketStorage.setString(keccak256("node.subnetID", _newNodeAddress), _subnetID);
        rocketStorage.setString(keccak256("node.instanceID", _newNodeAddress), _instanceID);
        rocketStorage.setString(keccak256("node.regionID", _newNodeAddress), _regionID);
        rocketStorage.setUint(keccak256("node.averageLoad", _newNodeAddress), 0);
        rocketStorage.setUint(keccak256("node.lastCheckin", _newNodeAddress), now);
        rocketStorage.setBool(keccak256("node.active", _newNodeAddress), true);
        rocketStorage.setBool(keccak256("node.exists", _newNodeAddress), true);
        // We store our nodes in an key/value array, so set its index so we can use an array to find it if needed
        rocketStorage.setUint(keccak256("node.index", _newNodeAddress), nodeCountTotal);
        // Update total nodes
        rocketStorage.setUint(keccak256("nodes.total"), nodeCountTotal + 1);
        // We also index all our nodes so we can do a reverse lookup based on its array index
        rocketStorage.setAddress(keccak256("nodes.index.reverse", nodeCountTotal), _newNodeAddress);
        // Fire the event
        NodeRegistered(_newNodeAddress, now);
        // Now create a minipool for that node to use
        
        // All good
        return true;
    } 

    /// @dev Remove a node from the Rocket Pool network
    /// @param _nodeAddress Address of the node
    function nodeRemove(address _nodeAddress) public onlyRegisteredNode(_nodeAddress) onlyOwner {
        // Get the main Rocket Pool contract
        RocketPoolInterface rocketPool = RocketPoolInterface(rocketStorage.getAddress(keccak256("contract.name", "rocketPool")));
        // Check the node doesn't currently have any registered mini pools associated with it
        require(rocketPool.getPoolsFilterWithNodeCount(_nodeAddress) == 0);
        // Get total nodes
        uint256 nodesTotal = rocketStorage.getUint(keccak256("nodes.total"));
        // Now remove this nodes data from storage
        uint256 nodeIndex = rocketStorage.getUint(keccak256("node.index", _nodeAddress));
        rocketStorage.deleteString(keccak256("node.providerID", _nodeAddress));
        rocketStorage.deleteString(keccak256("node.subnetID", _nodeAddress));
        rocketStorage.deleteString(keccak256("node.instanceID", _nodeAddress));
        rocketStorage.deleteString(keccak256("node.regionID", _nodeAddress));
        rocketStorage.deleteUint(keccak256("node.lastCheckin", _nodeAddress));
        rocketStorage.deleteBool(keccak256("node.active", _nodeAddress));
        rocketStorage.deleteBool(keccak256("node.exists", _nodeAddress));
        rocketStorage.deleteUint(keccak256("node.index", _nodeAddress));
        // Delete reverse lookup
        rocketStorage.deleteAddress(keccak256("nodes.index.reverse", nodeIndex));
        // Update total
        rocketStorage.setUint(keccak256("nodes.total"), nodesTotal - 1);
        // Now reindex the remaining nodes
        nodesTotal = rocketStorage.getUint(keccak256("nodes.total"));
        // Loop
        for (uint i = nodeIndex+1; i <= nodesTotal; i++) {
            address nodeAddress = rocketStorage.getAddress(keccak256("nodes.index.reverse", i));
            uint256 newIndex = i - 1;
            rocketStorage.setUint(keccak256("node.index", nodeAddress), newIndex);
            rocketStorage.setAddress(keccak256("nodes.index.reverse", newIndex), nodeAddress);
        }
        // Fire the event
        NodeRemoved(_nodeAddress, now);
    } 

    /// @dev Nodes will checkin with Rocket Pool at a set interval (15 mins) to do things like report on average node server load, get validator contracts to vote, set nodes to inactive that have not checked in an unusally long amount of time etc. Only registered nodes can call this.
    /// @param _currentLoadAverage The average server load for the node over the last 15 mins
    function nodeCheckin(uint256 _currentLoadAverage) public onlyRegisteredNode(msg.sender) {
        // Get the main pool contract
        RocketPoolInterface rocketPool = RocketPoolInterface(rocketStorage.getAddress(keccak256("contract.name", "rocketPool")));
        // Get our settings
        rocketSettings = RocketSettingsInterface(rocketStorage.getAddress(keccak256("contract.name", "rocketSettings")));
        // Fire the event
        NodeCheckin(msg.sender, _currentLoadAverage, now);
        // Updates the current 15 min load average on the node, last checkin time etc
        // Get the last checkin and only update if its changed to save on gas
        if (rocketStorage.getUint(keccak256("node.averageLoad", msg.sender)) != _currentLoadAverage) {
            rocketStorage.setUint(keccak256("node.averageLoad", msg.sender), _currentLoadAverage);
        }
        // Update the current checkin time
        rocketStorage.setUint(keccak256("node.lastCheckin", msg.sender), now);
        // Now check with the main Rocket Pool contract what pool actions currently need to be done
        // This method is designed to only process one minipool from each node checkin every 15 mins to prevent the gas block limit from being exceeded and make load balancing more accurate
        // 1) Assign a node to a new minipool that can be launched
        // 2) Request deposit withdrawal from Casper for any minipools currently staking
        // 3) Actually withdraw the deposit from Casper once it's ready for withdrawal
        rocketPool.poolNodeActions();  
        // Now see what nodes haven't checked in recently and disable them if needed to prevent new pools being assigned to them
        if (rocketSettings.getSmartNodeSetInactiveAutomatic() == true) {
            // Create an array at the length of the current nodes, then populate it
            address[] memory nodes = new address[](getNodeCount());
            // Get each node now and check
            for (uint32 i = 0; i < nodes.length; i++) {
                // Get our node address
                address currentNodeAddress = rocketStorage.getAddress(keccak256("nodes.index.reverse", i));
                // We've already checked in as this node above
                if (msg.sender != currentNodeAddress) {
                    // Has this node reported in recently? If not, it may be down or in trouble, deactivate it to prevent new pools being assigned to it
                    if (rocketStorage.getUint(keccak256("node.lastCheckin", currentNodeAddress)) < (now - rocketSettings.getSmartNodeSetInactiveDuration()) && rocketStorage.getBool(keccak256("node.active", currentNodeAddress)) == true) {
                        // Disable the node - must be manually reactivated by the function above when its back online/running well
                        rocketStorage.setBool(keccak256("node.active", currentNodeAddress), false);
                        // Fire the event
                        NodeActiveStatus(currentNodeAddress, false, now);
                    }
                }
            }
        } 
    }

    /// @dev Create a minipool contract to be assigned to users when needed, node creates this contract so Casper will match the signatures correctly when the contract votes
    /// @param _amount The amount of minipool contracts to create, be wary of exceeding the gas block limit
    /// @param _poolStakingTimeID The staking duration ID for this pool. Various pools can exist with different durations depending on the users needs.
    function nodeCreateMinipool(uint256 _amount, uint256 _poolStakingTimeID) external onlyRegisteredNode(msg.sender) {
        // Start creating, if this fails, reduce the amount of contracts to create, they are fairly expensive
        if (_amount > 0) {
            // Get the main pool contract
            RocketPoolInterface rocketPool = RocketPoolInterface(rocketStorage.getAddress(keccak256("contract.name", "rocketPool")));
            for (uint32 i = 0; i < _amount; i++) { 
               // Create a new minipool via RocketPool which controls all main pool actions
               // Has to be created by a node to ensure the signatures match when talking to Casper
               rocketPool.createPool(_poolStakingDuration, msg.sender);  
            }
        }
    }


    /// @dev Create a minipool contract to be assigned to users when needed, node creates this contract so Casper will match the signatures correctly when the contract votes
    /// @param _amount The amount of minipool contracts to create, be wary of exceeding the gas block limit
    /// @param _poolStakingDuration The staking duration of this pool in seconds. Various pools can exist with different durations depending on the users needs.
    /*
    function nodeCreateMinipool(uint256 _amount, uint256 _poolStakingDuration) external minipoolsAllowedToBeCreated onlyRegisteredNode(msg.sender) {
        // Start creating, if this fails, reduce the amount of contracts to create, they are fairly expensive
        if (_amount > 0) {
            for (uint32 i = 0; i < _amount; i++) {
                /// @dev Create a new pool, only RocketNode can call this as
                // Create the new pool and add it to our list
                RocketFactoryInterface rocketFactory = RocketFactoryInterface(rocketStorage.getAddress(keccak256("contract.name", "rocketFactory")));
                // Ok make the minipool contract now
                address newPoolAddress = rocketFactory.createRocketPoolMini(_poolStakingDuration);
                // Add the mini pool to the primary persistent storage so any contract upgrades won't effect the current stored mini pools
                // Check it doesn't already exist
                require(!rocketStorage.getBool(keccak256("minipool.exists", newPoolAddress)));
                // Get how many minipools we currently have  
                uint256 minipoolCountTotal = rocketStorage.getUint(keccak256("minipools.total")); 
                // Ok now set our data to key/value pair storage
                rocketStorage.setBool(keccak256("minipool.exists", newPoolAddress), true);
                // We store our data in an key/value array, so set its index so we can use an array to find it if needed
                rocketStorage.setUint(keccak256("minipool.index", newPoolAddress), minipoolCountTotal);
                // Update total minipools
                rocketStorage.setUint(keccak256("minipools.total"), minipoolCountTotal + 1);
                // We also index all our data so we can do a reverse lookup based on its array index
                rocketStorage.setAddress(keccak256("minipools.index.reverse", minipoolCountTotal), newPoolAddress);
                // Fire the event
                PoolCreated(newPoolAddress, _poolStakingDuration, now);
                // Return the new pool address
                return newPoolAddress; 
            }
        }
    }*/
}
