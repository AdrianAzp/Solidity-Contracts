
// Version de solidity del Smart Contract
// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.4.22 <0.9.0;
pragma experimental ABIEncoderV2;

// Informacion del Smart Contract
// Nombre: LuxuryTracker
// Logica: Implementa un registro de compra de objetos de lujo como bolsos y zapatillas, solo la propia tienda seria capaz de añadir datos y modificarlos.

contract LuxuryTracker{

    address public contractOwner;
    address productOwner;

    struct Venta{
        string buyer;
        string idProducto;
        string idTienda;
        uint   date;
        string datosProducto;
    }

    bool isActive;

//la key del vendedor sera el idCompra
    mapping(string => Venta) public owner;
    mapping(address => bool) private admin;

    event _newVenta(string buyer, string idProducto, string idTienda, uint date,string datosProducto);
    event _isOwner(Venta[] _venta);

     constructor() public {
        contractOwner = msg.sender;
        admin[msg.sender] = true;
        isActive = true;
    }


    function addAdmin(address _newAdmin) external {
        require(isActive, "Contract disabled");
        require(
            msg.sender == contractOwner,
            "Identity is not the contract owner"
        );
        require(!admin[_newAdmin], "Identity is already an admin");
        admin[_newAdmin] = true;
    }

        function deleteAdmin(address _noAdmin) external {
        require(isActive, "Contract disabled");
        require(
            msg.sender == contractOwner,
            "Identity is not the contract owner"
        );
        require(admin[_noAdmin], "Identity is not an admin");
        admin[_noAdmin] = false;
    }

    function isAdmin(address _entity) external view returns (bool) {
        require(isActive, "Contract disabled");
        require(
            msg.sender == contractOwner,
            "Identity is not the contract owner"
        );
        return (admin[_entity]);
    }

    function newVenta(string memory idCompra, string memory _buyer, string memory _idProducto, string memory _idTienda, string memory _datosProducto) public {
        require(admin[msg.sender]);
        owner[idCompra]= Venta(_buyer, _idProducto,_idTienda, block.timestamp, _datosProducto);
        emit _newVenta(_buyer, _idProducto,_idTienda, block.timestamp, _datosProducto);
    }

    function isOwner(string memory _idCompra) public view returns(string memory ,string memory ,string memory ,uint ,string memory){
       return(owner[_idCompra].buyer, owner[_idCompra].idProducto,owner[_idCompra].idTienda,owner[_idCompra].date,owner[_idCompra].datosProducto);
    }

//Como en blockchain no se puede hacer un delete la unica opcion para eliminar una compra seria sobreescribirla y usar la más reciente

}