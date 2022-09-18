// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract UltimateSoccer is Initializable, ERC721Upgradeable, ERC721EnumerableUpgradeable, ERC721URIStorageUpgradeable, PausableUpgradeable, AccessControlUpgradeable, ERC721BurnableUpgradeable {


     /// @dev This map contains every token listed
    mapping (uint256 => uint256) public tokenIdToPrice;

    /// @dev A mapping from player IDs to the address that owns them.
    mapping(uint256 => address) public playerIndexToOwner;

     //@dev Royalties info from token
    mapping (uint256 => RoyaltyInfo) public royaltyToken;

    // The addresses of the accounts (or contracts) that can execute actions within each roles.
    address public ceoAddress;
    address payable public cfoAddress;
    address public cooAddress;
     // Set in case the core contract is broken and an upgrade is required
    address public newContractAddress;

     struct RoyaltyInfo {
        uint64 royaltyFees;
        address payable royaltyAddress;
    }
    

    //Events

    event TransferEvent(address from, address to, uint256 tokenId);
    event ContractUpgrade(address newContract);

    //Modifiers

    /// @dev Access modifier for CEO-only functionality
    modifier onlyCEO() {
        require(msg.sender == ceoAddress);
        _;
    }

    /// @dev Access modifier for CFO-only functionality
    modifier onlyCFO() {
        require(msg.sender == cfoAddress);
        _;
    }

    /// @dev Access modifier for COO-only functionality
    modifier onlyCOO() {
        require(msg.sender == cooAddress);
        _;
    }


    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
         // the creator of the contract is the initial CEO
        ceoAddress = msg.sender;
        // the creator of the contract is also the initial COO 
        cooAddress = payable(msg.sender);
    }

    function initialize() initializer public {
        __ERC721_init("UltimateSoccer", "ULTS");
        __ERC721Enumerable_init();
        __ERC721URIStorage_init();
        __Pausable_init();
        __AccessControl_init();
        __ERC721Burnable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);

    }

    function _baseURI() internal pure override returns (string memory) {
        return "aqui va ipfs";
    }

    function pause() public onlyCEO {
        _pause();
    }

    function unpause() public onlyCEO {
        _unpause();
    }

    function safeMint(address to, uint256 tokenId, string memory uri)
        public
        onlyCOO
    {
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);
	playerIndexToOwner[tokenId] = to;
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId)
        internal
        whenNotPaused
        override(ERC721Upgradeable, ERC721EnumerableUpgradeable)
    {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    // The following functions are overrides required by Solidity.

    function _burn(uint256 tokenId)
        internal
        override(ERC721Upgradeable, ERC721URIStorageUpgradeable) onlyCOO
    {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721Upgradeable, ERC721URIStorageUpgradeable)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721Upgradeable, ERC721EnumerableUpgradeable, AccessControlUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    /// @dev Assigns ownership of a specific player to an address. Basically you're buying an nft
    function transferNFT(
        address from,
        address to,
        uint256 tokenId
    )  external  payable onlyCOO
        {
        uint256 price = tokenIdToPrice[tokenId];
        uint256 royalty = price*royaltyToken[tokenId].royaltyFees;
        uint256 fees = price*5/100;
        uint256 sellerProfit = price-royalty-fees;
        require(price > 0, 'This token is not for sale');
        require(msg.sender == ownerOf(tokenId));
        // transfer ownership
        playerIndexToOwner[tokenId] = to; 
        tokenIdToPrice[tokenId] = 0; // not for sale anymore
        cfoAddress.transfer(fees);
        royaltyToken[tokenId].royaltyAddress.transfer(royalty);
        payable(playerIndexToOwner[tokenId]).transfer(sellerProfit); // send the ETH to the seller
        
        _transfer(from, to, tokenId);
        // Emit the transfer event.
       emit TransferEvent(from, to, tokenId);
       
    }

    // @dev Allows the CFO to capture the balance available to the contract.
    function withdrawBalance() external onlyCFO {
        uint256 balance = address(this).balance;
        cfoAddress.transfer(balance);
        
    }

    function listToken(uint256 price, uint256 tokenId) public{
        require( msg.sender == ownerOf(tokenId));
        tokenIdToPrice[tokenId] = price;
    }

    function unlistToken(uint256 tokenId) public{
        require( msg.sender == ownerOf(tokenId));
        tokenIdToPrice[tokenId] = 0;
    }

    function royaltyMint(address to, uint256 tokenId, string memory uri, uint64 _royaltyFees, address _royaltyAddress) public onlyCOO {
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);
        setRoyalties(_royaltyAddress, _royaltyFees, tokenId);
	playerIndexToOwner[tokenId] = to;
    }

    function setRoyalties(address _royaltyAddress, uint64 _royaltyFees, uint256 _tokenId) internal{
        RoyaltyInfo storage info = royaltyToken[_tokenId];
        info.royaltyFees = _royaltyFees;
        info.royaltyAddress = payable(_royaltyAddress);
    }



    //reoles

 /// @dev Assigns a new address to act as the CEO. Only available to the current CEO.
    /// @param _newCEO The address of the new CEO
    function setCEO(address _newCEO) external onlyCEO {
        require(_newCEO != address(0));
        ceoAddress = _newCEO;
    }

    /// @dev Assigns a new address to act as the CFO. Only available to the current CEO.
    /// @param _newCFO The address of the new CFO
    function setCFO(address _newCFO) external onlyCEO {
        require(_newCFO != address(0));
        cfoAddress = payable(_newCFO);
    }

    /// @dev Assigns a new address to act as the COO. Only available to the current CEO.
    /// @param _newCOO The address of the new COO
    function setCOO(address _newCOO) external onlyCEO {
        require(_newCOO != address(0));
        cooAddress = _newCOO;
    }
}
