// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract FoodSafetyTracking {
    
    // Structure to store food product information
    struct FoodProduct {
        uint256 productId;
        string productName;
        string origin;
        address farmer;
        uint256 harvestDate;
        string currentLocation;
        address currentOwner;
        bool isContaminated;
        uint256 expiryDate;
        string[] trackingHistory;
    }
    
    // Structure for supply chain participants
    struct Participant {
        address participantAddress;
        string participantName;
        string role; // "farmer", "processor", "distributor", "retailer"
        bool isVerified;
    }
    
    // State variables
    mapping(uint256 => FoodProduct) public foodProducts;
    mapping(address => Participant) public participants;
    mapping(uint256 => address[]) public productOwnershipHistory;
    
    uint256 public productCounter;
    address public admin;
    
    // Events
    event ProductRegistered(uint256 indexed productId, string productName, address indexed farmer);
    event ProductTransferred(uint256 indexed productId, address indexed from, address indexed to, string location);
    event ContaminationReported(uint256 indexed productId, address indexed reporter);
    event ParticipantRegistered(address indexed participant, string role);
    
    // Modifiers
    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can perform this action");
        _;
    }
    
    modifier onlyVerifiedParticipant() {
        require(participants[msg.sender].isVerified, "Only verified participants can perform this action");
        _;
    }
    
    modifier onlyProductOwner(uint256 _productId) {
        require(foodProducts[_productId].currentOwner == msg.sender, "Only current owner can perform this action");
        _;
    }
    
    constructor() {
        admin = msg.sender;
        productCounter = 0;
    }
    
    /**
     * @dev Core Function 1: Register a new food product in the supply chain
     * @param _productName Name of the food product
     * @param _origin Origin location of the product
     * @param _expiryDate Expiry date of the product (timestamp)
     */
    function registerProduct(
        string memory _productName,
        string memory _origin,
        uint256 _expiryDate
    ) public onlyVerifiedParticipant returns (uint256) {
        require(bytes(_productName).length > 0, "Product name cannot be empty");
        require(_expiryDate > block.timestamp, "Expiry date must be in the future");
        
        productCounter++;
        uint256 newProductId = productCounter;
        
        // Initialize tracking history
        string[] memory initialHistory = new string[](1);
        initialHistory[0] = string(abi.encodePacked("Registered at ", _origin, " by ", participants[msg.sender].participantName));
        
        foodProducts[newProductId] = FoodProduct({
            productId: newProductId,
            productName: _productName,
            origin: _origin,
            farmer: msg.sender,
            harvestDate: block.timestamp,
            currentLocation: _origin,
            currentOwner: msg.sender,
            isContaminated: false,
            expiryDate: _expiryDate,
            trackingHistory: initialHistory
        });
        
        productOwnershipHistory[newProductId].push(msg.sender);
        
        emit ProductRegistered(newProductId, _productName, msg.sender);
        return newProductId;
    }
    
    /**
     * @dev Core Function 2: Transfer product ownership in the supply chain
     * @param _productId ID of the product to transfer
     * @param _newOwner Address of the new owner
     * @param _newLocation New location of the product
     */
    function transferProduct(
        uint256 _productId,
        address _newOwner,
        string memory _newLocation
    ) public onlyProductOwner(_productId) {
        require(_productId > 0 && _productId <= productCounter, "Invalid product ID");
        require(_newOwner != address(0), "Invalid new owner address");
        require(participants[_newOwner].isVerified, "New owner must be a verified participant");
        require(!foodProducts[_productId].isContaminated, "Cannot transfer contaminated product");
        require(block.timestamp < foodProducts[_productId].expiryDate, "Cannot transfer expired product");
        
        address previousOwner = foodProducts[_productId].currentOwner;
        
        // Update product information
        foodProducts[_productId].currentOwner = _newOwner;
        foodProducts[_productId].currentLocation = _newLocation;
        
        // Add to tracking history
        string memory historyEntry = string(abi.encodePacked(
            "Transferred to ", 
            participants[_newOwner].participantName,
            " at ",
            _newLocation
        ));
        foodProducts[_productId].trackingHistory.push(historyEntry);
        
        // Update ownership history
        productOwnershipHistory[_productId].push(_newOwner);
        
        emit ProductTransferred(_productId, previousOwner, _newOwner, _newLocation);
    }
    
    /**
     * @dev Core Function 3: Report contamination and trigger recall process
     * @param _productId ID of the contaminated product
     */
    function reportContamination(uint256 _productId) public onlyVerifiedParticipant {
        require(_productId > 0 && _productId <= productCounter, "Invalid product ID");
        require(!foodProducts[_productId].isContaminated, "Product already marked as contaminated");
        
        // Mark product as contaminated
        foodProducts[_productId].isContaminated = true;
        
        // Add to tracking history
        string memory historyEntry = string(abi.encodePacked(
            "CONTAMINATION REPORTED by ",
            participants[msg.sender].participantName
        ));
        foodProducts[_productId].trackingHistory.push(historyEntry);
        
        emit ContaminationReported(_productId, msg.sender);
    }
    
    // Additional utility functions
    
    /**
     * @dev Register a new participant in the supply chain
     * @param _participantAddress Address of the participant
     * @param _participantName Name of the participant
     * @param _role Role of the participant (farmer, processor, distributor, retailer)
     */
    function registerParticipant(
        address _participantAddress,
        string memory _participantName,
        string memory _role
    ) public onlyAdmin {
        require(_participantAddress != address(0), "Invalid participant address");
        require(bytes(_participantName).length > 0, "Participant name cannot be empty");
        
        participants[_participantAddress] = Participant({
            participantAddress: _participantAddress,
            participantName: _participantName,
            role: _role,
            isVerified: true
        });
        
        emit ParticipantRegistered(_participantAddress, _role);
    }
    
    /**
     * @dev Get complete tracking history of a product
     * @param _productId ID of the product
     * @return Array of tracking history strings
     */
    function getProductHistory(uint256 _productId) public view returns (string[] memory) {
        require(_productId > 0 && _productId <= productCounter, "Invalid product ID");
        return foodProducts[_productId].trackingHistory;
    }
    
    /**
     * @dev Get ownership history of a product
     * @param _productId ID of the product
     * @return Array of owner addresses
     */
    function getOwnershipHistory(uint256 _productId) public view returns (address[] memory) {
        require(_productId > 0 && _productId <= productCounter, "Invalid product ID");
        return productOwnershipHistory[_productId];
    }
    
    /**
     * @dev Check if a product is safe for consumption
     * @param _productId ID of the product
     * @return Boolean indicating if product is safe
     */
    function isProductSafe(uint256 _productId) public view returns (bool) {
        require(_productId > 0 && _productId <= productCounter, "Invalid product ID");
        return !foodProducts[_productId].isContaminated && 
               block.timestamp < foodProducts[_productId].expiryDate;
    }
}
