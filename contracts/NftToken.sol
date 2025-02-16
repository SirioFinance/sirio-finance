// SPDX-License-Identifier: BSD-3-Clause

pragma solidity ^0.8.25;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC721Burnable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract NftToken is ERC721, ERC721Burnable, Ownable {
    constructor(
        address initialOwner
    ) ERC721("MyToken", "MTK") Ownable(initialOwner) {}

    function safeMint(address to, uint256 tokenId) public onlyOwner {
        _safeMint(to, tokenId);
    }
}
