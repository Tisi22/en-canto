// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// NFT contract to inherit from.
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

// Helper functions OpenZeppelin provides.
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./libraries/Base64.sol";

import "hardhat/console.sol";

// Our contract inherits from ERC721, which is the standard NFT contract!
contract GameEncanto is ERC721, Ownable {

    struct CharacterAttributes {
        uint characterIndex;
        address owner;
        string name;
        string imageURI;
        uint hp;
        uint maxHp;
        uint attackDamage;
        uint damageGenerated;
    }

    struct BigBoss {
        string name;
        string imageURI;
        uint hp;
        uint maxHp;
        uint attackDamage;
    }

    BigBoss public bigBoss;

    //Token Id
    uint256 tokenId;

    uint256 mintCost;

    uint256 reviveCost;

    CharacterAttributes[] defaultCharacters;

    uint randNonce = 0;

    // We create a mapping from the nft's tokenId => that NFTs attributes.
    mapping(uint256 => CharacterAttributes) public nftHolderAttributes;

    event CharacterNFTMinted(
        address sender,
        uint256 tokenId,
        uint256 characterIndex
    );
    event AttackComplete(address sender, uint newBossHp, uint newPlayerHp);

    // A mapping from an address => the NFTs tokenId
    mapping(address => uint256) public nftHolders;

    constructor(
        string[] memory characterNames,
        string[] memory characterImageURIs,
        uint[] memory characterHp,
        uint[] memory characterAttackDmg,
        string memory bossName, // These new variables would be passed in via run.js or deploy.js.
        string memory bossImageURI,
        uint bossHp,
        uint bossAttackDamage
    )
        ERC721("En-canto", "E-CT")
    {
        // Initialize the boss. Save it to our global "bigBoss" state variable.
        bigBoss = BigBoss({
            name: bossName,
            imageURI: bossImageURI,
            hp: bossHp,
            maxHp: bossHp,
            attackDamage: bossAttackDamage
        });

        console.log(
            "Done initializing boss %s w/ HP %s, img %s",
            bigBoss.name,
            bigBoss.hp,
            bigBoss.imageURI
        );

        for (uint i = 0; i < characterNames.length; i++) {
            defaultCharacters.push(
                CharacterAttributes({
                    characterIndex: i,
                    name: characterNames[i],
                    owner: address(0),
                    imageURI: characterImageURIs[i],
                    hp: characterHp[i],
                    maxHp: characterHp[i],
                    attackDamage: characterAttackDmg[i],
                    damageGenerated:0
                })
            );

            CharacterAttributes memory c = defaultCharacters[i];

            // Hardhat's use of console.log() allows up to 4 parameters in any order of following types: uint, string, bool, address
            console.log(
                "Done initializing %s w/ HP %s, img %s",
                c.name,
                c.hp,
                c.imageURI
            );
        }

        tokenId++;

    }

    function setUpMintCost(uint256 _mintCost) external onlyOwner {
        mintCost = _mintCost;
    }

    function setUpReviveCost(uint256 _reviveCost) external onlyOwner {
        reviveCost = _reviveCost;
    }

    // Users would be able to hit this function and get their NFT based on the
    // characterId they send in!
    function mintCharacterNFT(uint _characterIndex) external payable {

        require(msg.value >= mintCost, "Not enough value sent");
        require(nftHolders[msg.sender] == 0, "You have already minted a character");

       
        nftHolderAttributes[tokenId] = CharacterAttributes({
            characterIndex: _characterIndex,
            name: defaultCharacters[_characterIndex].name,
            owner: msg.sender,
            imageURI: defaultCharacters[_characterIndex].imageURI,
            hp: defaultCharacters[_characterIndex].hp,
            maxHp: defaultCharacters[_characterIndex].maxHp,
            attackDamage: defaultCharacters[_characterIndex].attackDamage,
            damageGenerated: 0
        });

        console.log(
            "Minted NFT w/ tokenId %s and characterIndex %s",
            tokenId,
            _characterIndex
        );

        // Keep an easy way to see who owns what NFT.
        nftHolders[msg.sender] = tokenId;

        tokenId++;

        _safeMint(msg.sender, tokenId-1);

        emit CharacterNFTMinted(msg.sender, tokenId-1, _characterIndex);
    }

    function attackBoss() public {
        // Get the state of the player's NFT.
        CharacterAttributes storage player = nftHolderAttributes[
            nftHolders[msg.sender]
        ];

        console.log(
            "\nPlayer w/ character %s about to attack. Has %s HP and %s AD",
            player.name,
            player.hp,
            player.attackDamage
        );
        console.log(
            "Boss %s has %s HP and %s AD",
            bigBoss.name,
            bigBoss.hp,
            bigBoss.attackDamage
        );

        // Make sure the player has more than 0 HP.
        require(player.hp > 0, "Error: character must have HP to attack boss.");

        // Make sure the boss has more than 0 HP.
        require(
            bigBoss.hp > 0,
            "Error: boss must have HP to attack character."
        );

        // Allow player to attack boss.
        console.log("%s swings at %s...", player.name, bigBoss.name);
       
        if (randomInt(10) > 2) {
             // by passing 10 as the mod, we elect to only grab the last digit (0-9) of the hash!
            bigBoss.hp = bigBoss.hp - player.attackDamage;

            //Track damage to the boss by he player
            player.damageGenerated += player.attackDamage;

            checkBossDefeated(msg.sender);

        } else {
            console.log("%s missed!\n", player.name);
        }
        
        // Allow boss to attack player.
      
        if (randomInt(10) > 3) {
            player.hp = player.hp - bigBoss.attackDamage;
            if(player.hp <0){
                player.hp = 0;
            }
        } else {
            console.log("%s missed!\n", bigBoss.name);
        }
        
        emit AttackComplete(msg.sender, bigBoss.hp, player.hp);
    }

    

    function checkBossDefeated(address addr) internal {
        if(bigBoss.hp <= 0){
            bigBoss.hp = 0;
            distributeReward(addr);
            console.log("The boss is dead!");
        }
    }


    function distributeReward(address _lastHit) internal {
        uint256 damage = 0;
        address winner;

        for(uint i = 0; i < defaultCharacters.length; i++){
            if(defaultCharacters[i].damageGenerated > damage){
                damage = defaultCharacters[i].damageGenerated;
                winner = defaultCharacters[i].owner;
            }
        }

        sendRewards(winner, _lastHit);
        
    }

    function sendRewards(address _winner, address lastHit) internal {

        uint256 amount = address(this).balance;
        (bool success1, ) = _winner.call{value: amount/2}("");
        (bool success2, ) = owner().call{value: amount/10}("");
        (bool success3, ) = lastHit.call{value: (amount/10) * 4 }("");
        
        require(success1 && success2 && success3, "Transfer failed");

        console.log("Winner: %s\n Last Hit: %s", nftHolders[_winner], nftHolders[lastHit]);
    }

    function randomInt(uint _modulus) internal returns (uint) {
        randNonce++; // increase nonce
        return
            uint(
                keccak256(
                    abi.encodePacked(
                        block.timestamp, // an alias for 'block.timestamp'
                        msg.sender, // your address
                        randNonce
                    )
                )
            ) % _modulus; // modulo using the _modulus argument
    }

    function revive() public payable {
        require(msg.value >= reviveCost, "Not enough value sent");

        nftHolderAttributes[nftHolders[msg.sender]].hp = nftHolderAttributes[nftHolders[msg.sender]].maxHp;

    }

    function checkIfUserHasNFT()
        public
        view
        returns (CharacterAttributes memory)
    {
        // Get the tokenId of the user's character NFT
        uint256 userNftTokenId = nftHolders[msg.sender];
        // If the user has a tokenId in the map, return their character.
        if (userNftTokenId > 0) {
            return nftHolderAttributes[userNftTokenId];
        }
        // Else, return an empty character.
        else {
            CharacterAttributes memory emptyStruct;
            return emptyStruct;
        }
    }

    function getAllDefaultCharacters()
        public
        view
        returns (CharacterAttributes[] memory)
    {
        return defaultCharacters;
    }

    function getBigBoss() public view returns (BigBoss memory) {
        return bigBoss;
    }

    function tokenURI(
        uint256 _tokenId
    ) public view override returns (string memory) {
        CharacterAttributes memory charAttributes = nftHolderAttributes[
            _tokenId
        ];

        string memory strHp = Strings.toString(charAttributes.hp);
        string memory strMaxHp = Strings.toString(charAttributes.maxHp);
        string memory strAttackDamage = Strings.toString(
            charAttributes.attackDamage
        );

        string memory json = Base64.encode(
            bytes(
                string(
                    abi.encodePacked(
                        '{"name": "',
                        charAttributes.name,
                        " -- NFT #: ",
                        Strings.toString(_tokenId),
                        '", "description": "An epic NFT", "image": "ipfs://',
                        charAttributes.imageURI,
                        '", "attributes": [ { "trait_type": "Health Points", "value": ',
                        strHp,
                        ', "max_value":',
                        strMaxHp,
                        '}, { "trait_type": "Attack Damage", "value": ',
                        strAttackDamage,
                        "} ]}"
                    )
                )
            )
        );

        string memory output = string(
            abi.encodePacked("data:application/json;base64,", json)
        );

        return output;
    }

    // Sould bound tokens --> Block token transfers
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 _tokenId, /* firstTokenId */
        uint256 batchSize
    ) internal virtual override{
    require(from == address(0), "Err: token transfer is BLOCKED");   
    super._beforeTokenTransfer(from, to, _tokenId, batchSize);  
    }

    // Function to receive value msg.data must be empty
    receive() external payable {}

    // Fallback function is called when msg.data is not empty
    fallback() external payable {}
}
