// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity 0.8.18;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract EventTicket is ERC721, ERC721Pausable, AccessControl {
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    //bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    uint256 private _nextTokenId = 1;
    string public _baseUri;
    string private _name; // Nombre del token
    string private _symbol; // Símbolo del token
    uint _capacity;
    mapping(uint256 => uint256) public _price;
    mapping(uint256 => address) public _PriceReceiver;
    mapping(uint256 => bool) public _ticketUsed;
    uint[] public _forSale_ticket;
    uint[] public _forSale_collectible;
    uint public _date_admission;

    constructor(address defaultAdmin, address pauser, string memory baseUri, string memory symbol, string memory name, uint capacity, uint date_admission)
        ERC721(name, symbol)
    {
        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
        _grantRole(PAUSER_ROLE, pauser);
        //_grantRole(MINTER_ROLE, minter);
        _baseUri = baseUri;
        _name = name; // Asignar el nombre
        _symbol = symbol; // Asignar el símbolo
        _capacity = capacity;
        _date_admission = date_admission;
    }

    function _baseURI() internal view override returns (string memory) {
        return _baseUri;
    }

    /*
    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }
    */
    function _updateCapacity(uint capacity) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _capacity = capacity;
    }

    function _updateDate(uint date) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _date_admission = date;
    }

    function _updatePrice(uint id, uint price) external {
        require( _PriceReceiver[id] == msg.sender, "Error, this token doesnt belongs to you");
        _price[id] = price;
    }

    function get_index(uint[] memory arr, uint id) public pure returns (uint) {
      uint index = 0;
      for (uint i = 0; i < arr.length; i++) 
      {
        if (arr[i] == id){
          index = i +1;
          break;
        }
      }
      return index;
    }

    function get_FSticket() external view returns (uint[] memory) {
        return _forSale_ticket;
    }

    function get_FScollectible() external view returns(uint[] memory) {
        return _forSale_collectible;
    }

    function safeMint(uint price) public payable  {
        require(_capacity >= _nextTokenId, "There is no more capacity");
        require(msg.value == price);
        address to = msg.sender;
        uint256 tokenId = _nextTokenId++;
        _price[tokenId] = price;
        _PriceReceiver[tokenId] = to;
        _ticketUsed[tokenId] = false;
        //TODO: enviar compra al admin o al contrato, por ahora dejarla en el contato y hacer una función de retiro
        _safeMint(to, tokenId);
    }

    modifier available(uint id) {
        require(_ticketUsed[id] == false, "Error, this ticket has been used");
        require(block.timestamp <= _date_admission, "The ticket is no longer valid");
        _;
    }

    function buy_ticket(uint id) external payable available(id) {
        //require(_exists(id), "Error, wrong Token id");
        require(msg.value == _price[id], "Error, the amount sent does not match the Ticket's price");
        uint index = get_index(_forSale_ticket, id);
        require(index > 0, "The Ticket is not for sale");

        address oldOwner = _PriceReceiver[id];
        _PriceReceiver[id] = msg.sender;
        _transfer(address(this), msg.sender, id);
        address payable direccionPayable = payable(oldOwner);
        direccionPayable.transfer(msg.value);

        delete _forSale_ticket[index-1];
    }

    function sell_ticket(uint id, uint price) external available(id) {
        require( _PriceReceiver[id] == msg.sender, "Error, this token doesnt belongs to you");
        _price[id] = price;
        _transfer(msg.sender, address(this), id);

        _forSale_ticket.push(id);
    }

    function readTicket(uint id) external onlyRole(PAUSER_ROLE){
        require(_ticketUsed[id] == false, "The ticket has already been read");
        _ticketUsed[id] = true;
    }

    function withdraw() external onlyRole(DEFAULT_ADMIN_ROLE){
       // Verificar que hay fondos disponibles en el contrato
        uint256 balance = address(this).balance;
        require(balance > 0, "There is not available fonds to withdraw");

        // Transferir los fondos al propietario
        payable(msg.sender).transfer(balance);
    
    }

    function cancelSell(uint id) external {
        require(_PriceReceiver[id] == msg.sender, "Error, this token doesnt belongs to you");
        _transfer(address(this), msg.sender, id);
    }

    modifier not_available(uint id) {
        require(_ticketUsed[id] == true || block.timestamp >= _date_admission, "Error, this Ticket has not become a colletible");
        _;
    }

    function buy_collectible(uint id) external payable not_available(id) {
        require(msg.value == _price[id], "Error, the amount sent does not match the Ticket's price");
        uint index = get_index(_forSale_collectible, id);
        require(index > 0, "The Ticket is not for sale");

        address oldOwner = _PriceReceiver[id];
        _PriceReceiver[id] = msg.sender;
        _transfer(address(this), msg.sender, id);
        address payable direccionPayable = payable(oldOwner);
        direccionPayable.transfer(msg.value);

        delete _forSale_collectible[index-1];
    }

    function sell_collectible(uint id, uint price) external not_available(id) {
        require( _PriceReceiver[id] == msg.sender, "Error, this token doesnt belongs to you");
        _price[id] = price;
        _transfer(msg.sender, address(this), id);

        _forSale_collectible.push(id);
    }

    // The following functions are overrides required by Solidity.

    function _update(address to, uint256 tokenId, address auth)
        internal
        override(ERC721, ERC721Pausable)
        returns (address)
    {
        return super._update(to, tokenId, auth);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}

