//
//  GameScene.swift
//  SpriteKitSimpleGame
//
//  Created by Eddie Lee on 15/01/2016.
//  Copyright © 2016 Eddie Lee. All rights reserved.
//

import SpriteKit
import GameplayKit

struct PhysicsCategory {
    static let Spider:  UInt32 = 0
    static let Bug:     UInt32 = 0b1
    static let Web:     UInt32 = 0b10
    static let None:    UInt32 = UInt32.max
}

enum Layer: CGFloat {
    case Background
    case BackgroundDetail
    case DeadBug
    case Web
    case Player
    case Bug
    case Hud
}

enum BugType: Int {
    case Ladybird, Fly, Wasp
    
    func spriteName() -> String {
        switch self {
        case .Ladybird:
            return "ladybird"
        case .Fly:
            return "fly"
        case .Wasp:
            return "wasp"
        }
    }
    
    func speed() -> Double {
        switch self {
        case .Ladybird:
            return 5
        case .Fly:
            return 4
        case .Wasp:
            return 3
        }
    }
    
    private static let _count: BugType.RawValue = {
        var maxValue: Int = 0
        while let _ = BugType(rawValue: ++maxValue) { }
        return maxValue
    }()
    
    static func random(randomSource: GKRandomSource) -> BugType {
        let random = GKRandomDistribution(randomSource: randomSource, lowestValue: 0, highestValue: _count - 1)
        let index = random.nextInt()
        return BugType(rawValue: index)!
    }
}

struct GameStats {
    var bugsKilled = 0    
    var shotsFired = 0
    
    let pointPerKill = 5;
    let pointsPerShot = -1
    
    func calculateScore() -> Int {
        var score = 0
        
        score += bugsKilled * pointPerKill
        score += shotsFired * pointsPerShot
        
        if (score < 0) {
            score = 0
        }
        
        return score
    }
}

class GameScene: SKScene, SKPhysicsContactDelegate {
    var player: SKSpriteNode!
    var scoreLabel: SKLabelNode!
    
    var gameStats = GameStats()
    
    var bugPositionRandom: GKRandomDistribution!
    var bugTypeRandomSource = GKRandomSource()
    
    var lifeSprites = [SKSpriteNode]()
    let MaxNumberOfLives = 3
    var currentNumberOfLives = 0

    override func didMoveToView(view: SKView) {
        physicsWorld.contactDelegate = self
        physicsWorld.gravity = CGVector(dx: 0, dy: 0)
        
        setupLayout()
        
        let screenPadding = 25
        bugPositionRandom = GKRandomDistribution(lowestValue: screenPadding, highestValue: Int(size.height) - screenPadding)
        
        startGame()
    }
    
    
    
    // MARK: Setup
    
    func setupLayout() {
        addBackground()
        addBackgroundDetail()
        addPlayer()
        addHud()
    }
    
    func addBackground() {
        let backgroundNode = SKNode()
        
        let grassSprite = SKSpriteNode(imageNamed: "grass")
        grassSprite.anchorPoint = CGPoint.zero
        grassSprite.zPosition = Layer.Background.rawValue
                
        let xBlocks = Int(size.width / grassSprite.size.width)
        let yBlocks = Int(size.height / grassSprite.size.height)
        
        for xBlock in 0...xBlocks {
            for yBlock in 0...yBlocks {
                let tileNode = grassSprite.copy() as! SKSpriteNode
                let xPos = grassSprite.size.width * CGFloat(xBlock)
                let yPos = grassSprite.size.height * CGFloat(yBlock)
                tileNode.position = CGPoint(x: xPos, y: yPos)
                backgroundNode.addChild(tileNode)
            }
        }
        
        addChild(backgroundNode)
    }
    
    func addBackgroundDetail() {
        let xPositionRandom = GKShuffledDistribution(lowestValue: 0, highestValue: Int(size.width))
        let yPositionRandom = GKShuffledDistribution(lowestValue: 0, highestValue: Int(size.height))
        
        for _ in 1...20 {
            let flower = SKSpriteNode(imageNamed: "flower")
            flower.zPosition = Layer.BackgroundDetail.rawValue
            flower.position = CGPoint(x: xPositionRandom.nextInt(), y: yPositionRandom.nextInt())
            addChild(flower)
            
            let daisy = SKSpriteNode(imageNamed: "daisy")
            daisy.zPosition = Layer.BackgroundDetail.rawValue
            daisy.position = CGPoint(x: xPositionRandom.nextInt(), y: yPositionRandom.nextInt())
            addChild(daisy)
        }
    }
    
    func addPlayer() {
        player = SKSpriteNode(imageNamed: "spider")
        player.position = CGPoint(x: size.width * 0.1, y: size.height * 0.5)
        player.anchorPoint = CGPoint(x: 0.34, y: 0.5)
        player.zPosition = Layer.Player.rawValue

        addChild(player)
    }
    
    func addHud() {
        addScoreLabel()
        addLivesNode()
    }

    func addScoreLabel() {
        scoreLabel = SKLabelNode()
        scoreLabel.text = "Score: 0"
        scoreLabel.horizontalAlignmentMode = .Left
        scoreLabel.fontSize = 25
        scoreLabel.fontColor = SKColor.blackColor()
        scoreLabel.position = CGPoint(x: 10, y: size.height - 35)
        scoreLabel.zPosition = Layer.Hud.rawValue
        addChild(scoreLabel)
    }
    
    func addLivesNode() {
        let livesContainer = SKNode()
        livesContainer.name = "lives-container"
        
        for lifeNumber in 1...MaxNumberOfLives {
            let lifeSprite = SKSpriteNode(imageNamed: "heart")
            lifeSprite.name = "life-\(lifeNumber)"
            
            let lifeSpriteXPos = (lifeSprite.size.width + 5) * CGFloat(lifeNumber)
            
            lifeSprite.position = CGPoint(x: lifeSpriteXPos, y: 0)
            lifeSprite.runAction(SKAction.repeatActionForever(SKAction.sequence([
                SKAction.scaleTo(0.8, duration: 0.5),
                SKAction.scaleTo(1.0, duration: 0.5)
            ])), withKey: "animate")
            lifeSprites.append(lifeSprite)
            
            livesContainer.addChild(lifeSprite)
        }
        
        livesContainer.zPosition = Layer.Hud.rawValue
        livesContainer.position = CGPoint(x: size.width / 2, y: size.height - 20)
        
        addChild(livesContainer)
    }
    
    
    
    // MARK: Game life cycle
    
    func startGame() {
        currentNumberOfLives = MaxNumberOfLives
        
        runAction(SKAction.repeatActionForever(
            SKAction.sequence([
                SKAction.runBlock(addBug),
                SKAction.waitForDuration(1)
            ])
        ), withKey: "spawn")
    }
    
    func bugDidReachTarget() {
        currentNumberOfLives--;
        
        if currentNumberOfLives < 1 {
            self.gameOver()
        } else {
            updateRemainingLives()
        }
    }
    
    func gameOver() {
        // Stop new bugs from spawning
        self.removeActionForKey("spawn")
        
        // Transition to Game Over Scene
        let gameOverScene = GameOverScene(size: self.size)
        gameOverScene.gameScore = gameStats.calculateScore()
        let transition = SKTransition.fadeWithColor(UIColor.blackColor(), duration: 0.5)
        self.view?.presentScene(gameOverScene, transition: transition)
    }
    
    func updateScore() {
        scoreLabel.text = "Score: \(gameStats.calculateScore())"
    }
    
    func updateRemainingLives() {
        for (index, lifeSprite) in lifeSprites.enumerate() {
            let lifeNumber = index + 1
            
            if lifeNumber > currentNumberOfLives {
                lifeSprite.texture = SKTexture(imageNamed: "heart-dead")
                lifeSprite.removeActionForKey("animate")
                lifeSprite.setScale(0.8)
            }
        }
    }
    
    
    // MARK: Game actions
    
    func addBug() {
        let bugType = BugType.random(bugTypeRandomSource)
        let bug = getBugSprite(bugType.spriteName())
        
        let yPosition = CGFloat(bugPositionRandom.nextInt())
        let startPosition = CGPoint(x: size.width + bug.size.width / 2, y: yPosition)
        let endPosition = CGPoint(x: -bug.size.width / 2, y: yPosition)
        
        bug.position = startPosition
        bug.constraints = [SKConstraint.orientToPoint(endPosition, offset: SKRange(constantValue: 0))]
        
        bug.runAction(SKAction.sequence([
            SKAction.moveTo(endPosition, duration: bugType.speed()),
            SKAction.runBlock({
                self.bugDidReachTarget()
            }),
            SKAction.removeFromParent()
        ]), withKey: "move")
        
        addChild(bug)
    }
    
    func shootWebAtPoint(point: CGPoint) {
        gameStats.shotsFired++
        updateScore()
        
        
        let web = SKSpriteNode(imageNamed: "web-shoot")
        web.position = player.position
        
        web.physicsBody = SKPhysicsBody(circleOfRadius: web.size.height/2)
        web.physicsBody?.dynamic = false
        web.physicsBody?.categoryBitMask = PhysicsCategory.Web
        web.physicsBody?.contactTestBitMask = PhysicsCategory.Bug
        web.physicsBody?.usesPreciseCollisionDetection = true
        
        web.zPosition = Layer.Web.rawValue
        web.setScale(0)
        
        let webDestination = getTargetDestination(web.position, destinationPoint: point)
        
        web.constraints = [SKConstraint.orientToPoint(webDestination, offset: SKRange(constantValue: 0))]
        
        let animateWebAction = SKAction.scaleTo(1, duration: 0.1)
        let moveWebAction = SKAction.sequence([
            SKAction.moveTo(webDestination, duration: 2.0),
            SKAction.removeFromParent()
        ])
        
        web.runAction(SKAction.group([
            animateWebAction,
            moveWebAction
        ]))
        
        addChild(web)
    }
    
    func webDidCollideWithBug(web: SKSpriteNode, bug: SKSpriteNode) {
        gameStats.bugsKilled++
        updateScore()
        
        web.removeFromParent()
        
        bug.removeActionForKey("animate")
        bug.removeActionForKey("move")
        bug.zPosition = Layer.DeadBug.rawValue
        bug.texture = SKTexture(imageNamed: "\(bug.name!)-web")
        bug.physicsBody = nil
        
        bug.runAction(SKAction.sequence([
            SKAction.waitForDuration(3),
            SKAction.fadeAlphaTo(0, duration: 1),
            SKAction.removeFromParent()
        ]))
    }
    
    
    
    // MARK: Player input
    
    override func touchesBegan(touches: Set<UITouch>, withEvent event: UIEvent?) {
        guard let touch = touches.first else {
            return
        }
        
        let touchLocation = touch.locationInNode(self)
        
        player.constraints = [SKConstraint.orientToPoint(touchLocation, offset: SKRange(constantValue: 0))]
    }
    
    override func touchesMoved(touches: Set<UITouch>, withEvent event: UIEvent?) {
        guard let touch = touches.first else {
            return
        }
        
        let touchLocation = touch.locationInNode(self)
        
        player.constraints = [SKConstraint.orientToPoint(touchLocation, offset: SKRange(constantValue: 0))]
    }
    
    override func touchesEnded(touches: Set<UITouch>, withEvent event: UIEvent?) {
        guard let touch = touches.first else {
            return
        }
        
        let touchLocation = touch.locationInNode(self)
        
        player.constraints = [SKConstraint.orientToPoint(touchLocation, offset: SKRange(constantValue: 0))]
        shootWebAtPoint(touchLocation)
    }

    func didBeginContact(contact: SKPhysicsContact) {
        guard let web  = get(PhysicsCategory.Web, fromContact: contact) else {
            return
        }
        
        guard let bug = get(PhysicsCategory.Bug, fromContact: contact) else {
            return
        }
        
        webDidCollideWithBug(web, bug: bug)
    }
    
    
    
    // MARK: Helper methods
    
    
    
    func getBugSprite(named: String) -> SKSpriteNode {
        let bugSprite = SKSpriteNode(imageNamed: "\(named)-move-1")
        bugSprite.name = named
        
        let animateAction = SKAction.animateWithTextures([
            SKTexture(imageNamed: "\(named)-move-1"),
            SKTexture(imageNamed: "\(named)-move-2"),
            SKTexture(imageNamed: "\(named)-move-3"),
            SKTexture(imageNamed: "\(named)-move-4"),
            SKTexture(imageNamed: "\(named)-move-3"),
            SKTexture(imageNamed: "\(named)-move-2")
        ], timePerFrame: 0.1)
        
        bugSprite.runAction(SKAction.repeatActionForever(animateAction), withKey: "animate")
        
        bugSprite.physicsBody = SKPhysicsBody(circleOfRadius: bugSprite.size.height/2)
        bugSprite.physicsBody?.dynamic = true
        bugSprite.physicsBody?.categoryBitMask = PhysicsCategory.Bug
        bugSprite.physicsBody?.contactTestBitMask = PhysicsCategory.Web
        
        bugSprite.zPosition = Layer.Bug.rawValue
        
        return bugSprite
    }
    
    func get(type: UInt32, fromContact: SKPhysicsContact) -> SKSpriteNode? {
        if fromContact.bodyA.categoryBitMask == type {
            return getSpriteNode(fromContact.bodyA)
        }
        if fromContact.bodyB.categoryBitMask == type {
            return getSpriteNode(fromContact.bodyB)
        }
        
        return nil
    }
    
    func getSpriteNode(physicsBody: SKPhysicsBody) -> SKSpriteNode? {
        if let spriteNode = physicsBody.node as? SKSpriteNode {
            return spriteNode
        }
        
        return nil
    }
    
    func getTargetDestination(startPoint: CGPoint, destinationPoint: CGPoint) -> CGPoint {
        let pointOffset = destinationPoint - startPoint
        let shootDirection = pointOffset.normalized()
        let shootDistance = shootDirection * 1000
        let destination = shootDistance + startPoint
        
        return destination
    }
}