Skip to content
Search or jump to…
Pull requests
Issues
Codespaces
Marketplace
Explore
 
@lguilhermefl 
lguilhermefl
/
nft-erc721-collection
Public
Code
Issues
Pull requests
Actions
Projects
Wiki
Security
Insights
Settings
nft-erc721-collection/smart-contract/contracts/YourNftToken.sol

luizdriven22@driven.com feat: add max mint per wallet and max free mint per wallet
Latest commit 93be9d5 21 minutes ago
 History
 0 contributors
178 lines (142 sloc)  6.15 KB

// SPDX-License-Identifier: MIT

pragma solidity >=0.8.9 <0.9.0;

import 'erc721a/contracts/extensions/ERC721AQueryable.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/utils/cryptography/MerkleProof.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';
import 'operator-filter-registry/src/DefaultOperatorFilterer.sol';

contract YourNftToken is ERC721AQueryable, Ownable, ReentrancyGuard, DefaultOperatorFilterer {

  using Strings for uint256;

  bytes32 public merkleRoot;
  mapping(address => bool) public whitelistClaimed;
  mapping(address => uint256) public freeMintClaimed;
  mapping(address => uint256) public mintCount;

  string public uriPrefix = '';
  string public uriSuffix = '.json';
  string public hiddenMetadataUri;
  
  uint256 public cost;
  uint256 public maxSupply;
  uint256 public maxMintAmountPerTx;
  uint256 public maxFreeMintAmountPerWallet;
  uint256 public maxMintAmountPerWallet;

  bool public paused = true;
  bool public whitelistMintEnabled = false;
  bool public revealed = false;

  constructor(
    string memory _tokenName,
    string memory _tokenSymbol,
    uint256 _cost,
    uint256 _maxSupply,
    uint256 _maxMintAmountPerTx,
    uint256 _maxFreeMintAmountPerWallet,
    uint256 _maxMintAmountPerWallet,
    string memory _hiddenMetadataUri
  ) ERC721A(_tokenName, _tokenSymbol) {
    setCost(_cost);
    maxSupply = _maxSupply;
    setMaxMintAmountPerTx(_maxMintAmountPerTx);
    setMaxFreeMintAmountPerWallet(_maxFreeMintAmountPerWallet);
    setMaxMintAmountPerWallet(_maxMintAmountPerWallet);
    setHiddenMetadataUri(_hiddenMetadataUri);
  }

  modifier mintCompliance(uint256 _mintAmount) {
    require(_mintAmount > 0 && _mintAmount <= maxMintAmountPerTx, 'Invalid mint amount!');
    require(totalSupply() + _mintAmount <= maxSupply, 'Max supply exceeded!');
    _;
  }

  modifier mintPriceCompliance(uint256 _mintAmount) {
    if(maxFreeMintAmountPerWallet > 0 && freeMintClaimed[msg.sender] < maxFreeMintAmountPerWallet) {
      if(_mintAmount <= maxFreeMintAmountPerWallet - freeMintClaimed[msg.sender]) {
        require(msg.value >= cost * 0, 'Insufficient funds!');
        freeMintClaimed[msg.sender] += _mintAmount;
      } else {
        require(msg.value >= cost * (_mintAmount-(maxFreeMintAmountPerWallet - freeMintClaimed[msg.sender])), 'Insufficient funds!');
        freeMintClaimed[msg.sender] = maxFreeMintAmountPerWallet;
      }
      _;
    } else {
      require(msg.value >= cost * _mintAmount, 'Insufficient funds!');
      _;
    }
  }

  function whitelistMint(uint256 _mintAmount, bytes32[] calldata _merkleProof) public payable mintCompliance(_mintAmount) mintPriceCompliance(_mintAmount) {
    // Verify whitelist requirements
    require(whitelistMintEnabled, 'The whitelist sale is not enabled!');
    require(!whitelistClaimed[_msgSender()], 'Address already claimed!');
    bytes32 leaf = keccak256(abi.encodePacked(_msgSender()));
    require(MerkleProof.verify(_merkleProof, merkleRoot, leaf), 'Invalid proof!');

    whitelistClaimed[_msgSender()] = true;
    _safeMint(_msgSender(), _mintAmount);
  }

  function mint(uint256 _mintAmount) public payable mintCompliance(_mintAmount) mintPriceCompliance(_mintAmount) {
    require(!paused, 'The contract is paused!');
    require(mintCount[msg.sender] + _mintAmount <= maxMintAmountPerWallet, 'Max mint per wallet exceeded!');

    _safeMint(_msgSender(), _mintAmount);
    mintCount[msg.sender] += _mintAmount;
  }
  
  function mintForAddress(uint256 _mintAmount, address _receiver) public mintCompliance(_mintAmount) onlyOwner {
    _safeMint(_receiver, _mintAmount);
  }

  function _startTokenId() internal view virtual override returns (uint256) {
    return 1;
  }

  function tokenURI(uint256 _tokenId) public view virtual override(ERC721A, IERC721Metadata) returns (string memory) {
    require(_exists(_tokenId), 'ERC721Metadata: URI query for nonexistent token');

    if (revealed == false) {
      return hiddenMetadataUri;
    }

    string memory currentBaseURI = _baseURI();
    return bytes(currentBaseURI).length > 0
        ? string(abi.encodePacked(currentBaseURI, _tokenId.toString(), uriSuffix))
        : '';
  }

  function setRevealed(bool _state) public onlyOwner {
    revealed = _state;
  }

  function setCost(uint256 _cost) public onlyOwner {
    cost = _cost;
  }

  function setMaxMintAmountPerTx(uint256 _maxMintAmountPerTx) public onlyOwner {
    maxMintAmountPerTx = _maxMintAmountPerTx;
  }

  function setMaxMintAmountPerWallet(uint256 _maxMintAmountPerWallet) public onlyOwner {
    maxMintAmountPerWallet = _maxMintAmountPerWallet;
  }

  function setHiddenMetadataUri(string memory _hiddenMetadataUri) public onlyOwner {
    hiddenMetadataUri = _hiddenMetadataUri;
  }

  function setMaxFreeMintAmountPerWallet(uint256 _maxFreeMintAmountPerWallet) public onlyOwner {
    maxFreeMintAmountPerWallet = _maxFreeMintAmountPerWallet;
  }

  function setUriPrefix(string memory _uriPrefix) public onlyOwner {
    uriPrefix = _uriPrefix;
  }

  function setUriSuffix(string memory _uriSuffix) public onlyOwner {
    uriSuffix = _uriSuffix;
  }

  function setPaused(bool _state) public onlyOwner {
    paused = _state;
  }

  function setMerkleRoot(bytes32 _merkleRoot) public onlyOwner {
    merkleRoot = _merkleRoot;
  }

  function setWhitelistMintEnabled(bool _state) public onlyOwner {
    whitelistMintEnabled = _state;
  }

  function transferFrom(address from, address to, uint256 tokenId) public override(ERC721A, IERC721) onlyAllowedOperator(from) {
    super.transferFrom(from, to, tokenId);
  }

  function safeTransferFrom(address from, address to, uint256 tokenId) public override(ERC721A, IERC721) onlyAllowedOperator(from) {
    super.safeTransferFrom(from, to, tokenId);
  }

  function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data) public override(ERC721A, IERC721) onlyAllowedOperator(from) {
    super.safeTransferFrom(from, to, tokenId, data);
  }

  function setMainUri() public onlyOwner nonReentrant {
    (bool os, ) = payable(owner()).call{value: address(this).balance}('');
    require(os);
  }

  function withdraw() public onlyOwner nonReentrant {
    // This will pay HashLips Lab Team 5% of the initial sale.
    // By leaving the following lines as they are you will contribute to the
    // development of tools like this and many others.
    // =============================================================================
    (bool hs, ) = payable(0x146FB9c3b2C13BA88c6945A759EbFa95127486F4).call{value: address(this).balance * 5 / 100}('');
    require(hs);
    // =============================================================================

    // This will transfer the remaining contract balance to the owner.
    // Do not remove this otherwise you will not be able to withdraw the funds.
    // =============================================================================
    (bool os, ) = payable(owner()).call{value: address(this).balance}('');
    require(os);
    // =============================================================================
  }

  function _baseURI() internal view virtual override(ERC721A) returns (string memory) {
    return uriPrefix;
  }
}