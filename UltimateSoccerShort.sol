// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";




contract UltimateSoccerShort is Pausable, ERC721, ERC721URIStorage, ERC721Burnable {
    // This facet controls access control for UltimateSoccer. There are four roles managed here:
    //
    //     - The CEO: The CEO can reassign other roles and change the addresses of our dependent smart
    //         contracts. It is also the only role that can unpause the smart contract. It is initially
    //         set to the address that created the smart contract in the PlayersCore constructor.
    //
    //     - The CFO: The CFO can withdraw funds from PlayersCore and its auction contracts. 
    //
    //     - The COO: The COO can release special players to auction, and mint.
    //
    // While the CEO can assign any address to any role, the CEO address itself doesn't have the ability to act in those roles. This
    // restriction is intentional so that we aren't tempted to use the CEO address frequently out of
    // convenience. The less we use an address, the less likely it is that we somehow compromise the account.

    /// @dev This map contains every token listed
    mapping (uint256 => uint256) public tokenIdToPrice;

    /// @dev A mapping from player IDs to the address that owns them.
    mapping(uint256 => address) public playerIndexToOwner;

    // The addresses of the accounts (or contracts) that can execute actions within each roles.
    address public ceoAddress;
    address payable public cfoAddress;
    address public cooAddress;
     // Set in case the core contract is broken and an upgrade is required
    address public newContractAddress;

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


    constructor(string memory name_, string memory symbol_) ERC721(name_, symbol_){

        // the creator of the contract is the initial CEO
        ceoAddress = msg.sender;
        // the creator of the contract is also the initial COO 
        cooAddress = payable(msg.sender);
    }

    // @dev Allows the CFO to capture the balance available to the contract.
    function withdrawBalance() external onlyCFO {
        uint256 balance = address(this).balance;
        cfoAddress.transfer(balance);
        
    }

    /// @dev Assigns ownership of a specific player to an address. Basically you're buying an nft
    function transferNFT(
        address from,
        address to,
        uint256 tokenId
    )  external  payable
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


    function listToken(uint256 price, uint256 tokenId) public{
        require( msg.sender == ownerOf(tokenId));
        tokenIdToPrice[tokenId] = price;
    }

    function unlistToken(uint256 tokenId) public{
        require( msg.sender == ownerOf(tokenId));
        tokenIdToPrice[tokenId] = 0;
    }

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

    /////MINTING PART

    struct RoyaltyInfo {
        uint64 royaltyFees;
        address payable royaltyAddress;
    }
    
    //@dev Royalties info from token
    mapping (uint256 => RoyaltyInfo) public royaltyToken;

    function _baseURI() internal pure override returns (string memory) {
        return "ipfs://{IPFS CID}/";
    }

    function safeMint(address to, uint256 tokenId, string memory uri) public onlyCOO {
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);
    }


    function royaltyMint(address to, uint256 tokenId, string memory uri, uint64 _royaltyFees, address _royaltyAddress) public onlyCOO {
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);
        setRoyalties(_royaltyAddress, _royaltyFees, tokenId);
    }

    function setRoyalties(address _royaltyAddress, uint64 _royaltyFees, uint256 _tokenId) internal{
        RoyaltyInfo storage info = royaltyToken[_tokenId];
        info.royaltyFees = _royaltyFees;
        info.royaltyAddress = payable(_royaltyAddress);
    }


    function _beforeTokenTransfer(address from, address to, uint256 tokenId)
        internal  whenNotPaused
        override(ERC721)
    {
        _beforeTokenTransfer(from, to, tokenId);
    }

    
    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

     function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    // ERC-165 Compatibility (https://github.com/ethereum/EIPs/issues/165)
     function supportsInterface(bytes4 interfaceId)
            public
            view
            override(ERC721)
            returns (bool) 
    {
        return interfaceId == 0x2a55205a || super.supportsInterface(interfaceId);
    }


    /// @dev Used to mark the smart contract as upgraded, in case there is a serious
    ///  breaking bug. This method does nothing but keep track of the new contract and
    ///  emit a message indicating that the new address is set. It's up to clients of this
    ///  contract to update to the new contract address in that case. (This contract will
    ///  be paused indefinitely if such an upgrade takes place.)
    /// @param _v2Address new address
    function setNewAddress(address _v2Address) external onlyCEO whenPaused {
        newContractAddress = _v2Address;
       emit ContractUpgrade(_v2Address);
    }

    ///Pause unpause

    function pause() public onlyCEO{
        _pause();
    }

    function unpause() public onlyCEO{
        _unpause();
    }
}