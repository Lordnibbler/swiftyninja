//
//  GameScene.swift
//  swiftyninja
//
//  Created by iMac on 6/3/20.
//  Copyright © 2020 Lord Nibbler. All rights reserved.
//

import AVFoundation
import SpriteKit

enum ForceBomb {
    case never, always, random
}

// for allCases to use randomElement to pick random sequenceTypes
enum SequenceType : CaseIterable {
    case oneNoBomb      // enemy definitely not a bomb; exclusively when player first starts the game
    case one            // might be a bomb, not a bomb; exclusively when player first starts the game
    case twoWithOneBomb // two where 1 is bomb and 2 are not bombs
    case two            // amount of enemies
    case three          // amount of enemies
    case four           // amount of enemies
    case chain          // chain wont wait until previous enemy is off screen before creating new one
    case fastChain      // likewise but faster
}

class GameScene: SKScene {
    var gameScore: SKLabelNode!
    var score = 0 {
        didSet {
            gameScore.text = "Score \(score)"
        }
    }
    var livesImages = [SKSpriteNode]()
    var lives = 3
    
    var activeSliceBG: SKShapeNode!
    var activeSliceFG: SKShapeNode!
    
    var activeSlicePoints = [CGPoint]()
    
    var isSwooshSoundActive = false
    
    // all enemies in game scene
    var activeEnemies = [SKSpriteNode]()
    
    // more flexible audio player that can easily start/stop playback
    var bombSoundEffect: AVAudioPlayer?
    
    // time to wait between last enemy destroyed and new enemy created
    var popupTime = 0.9
    
    // store which enemies will be created
    var sequence = [SequenceType]()
    
    // where we are in the game relative to sequence array
    var sequencePosition = 0
    
    // how long to wait before creating new enemy when sequenceType is chain or fastChain
    var chainDelay = 3.0
        
    // when all enemries are destroyed and ready to create more
    var nextSequenceQueued = true
    
    var isGameEnded = false

    override func didMove(to view: SKView) {
        // called when scene is presented by a view
        
        let background = SKSpriteNode(imageNamed: "sliceBackground")
        background.position = CGPoint(x: 512, y: 384)
        background.blendMode = .replace
        background.zPosition = -1
        addChild(background)
        
        // sets gravity of physics simulation than less of earth default
        // so items stay in the air longer/less drag pulling down
        physicsWorld.gravity = CGVector(dx: 0, dy: -6)
        
        // all movement in the game to happen at a slightly slower rate
        physicsWorld.speed = 0.85
        
        // set up game
        print("*** -> set up game")
        createScore()
        createLives()
        createSlices()
        
        // make sequence for gameplay
        sequence = [.oneNoBomb, .oneNoBomb, .twoWithOneBomb, .twoWithOneBomb, .three, .one, .chain]
        
        // start creating enemies after 2 seconds
        print("*** -> creating sequence")
        for _ in 0...1000 {
            if let nextSequence = SequenceType.allCases.randomElement() {
                sequence.append(nextSequence)
            }
        }
        print("*** -> created sequence of length \(sequence.count)")
        
        // call tossEnemies after 2s of time has passed
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            print("*** -> first tossEnemies()")
            self?.tossEnemies()
        }
    }
    
    func createScore() {
        gameScore = SKLabelNode(fontNamed: "Chalkduster")
        gameScore.horizontalAlignmentMode = .left
        gameScore.fontSize = 48
        addChild(gameScore)
        
        gameScore.position = CGPoint(x: 8, y: 8)
        score = 0 // trigger property observer to set initial score label
    }
    
    func createLives() {
        print("*** -> createLives")
        // create 3 SKSpriteNode and position at top right corner of screen
        // add to livesImages array to show life count while playing
        for i in 0 ..< 3 {
            let spriteNode = SKSpriteNode(imageNamed: "sliceLife")
            spriteNode.position = CGPoint(x: CGFloat(834 + (i * 70)), y: 720)
            addChild(spriteNode)
            livesImages.append(spriteNode)
        }
    }
    
    func createSlices() {
        // track all player moves on screen recording an array of swipes
        // draw 2 slice shapes, 1 yellow and 1 white to make a "hot glow"
        // use zPosition to make sure slices are above everything else in game
        activeSliceBG = SKShapeNode()
        activeSliceBG.zPosition = 2
        
        activeSliceFG = SKShapeNode()
        activeSliceFG.zPosition = 3
        
        activeSliceBG.strokeColor = UIColor(red: 1, green: 0.9, blue: 0, alpha: 1)
        activeSliceBG.lineWidth = 9
        
        activeSliceFG.strokeColor = UIColor.white
        activeSliceFG.lineWidth = 5
        
        addChild(activeSliceBG)
        addChild(activeSliceFG)
    }
    
    func subtractLife() {
        lives -= 1

        // play sound and animate life being lost
        run(SKAction.playSoundFileNamed("wrong.caf", waitForCompletion: false))

        // remove life from images array
        var life: SKSpriteNode
        if lives == 2 {
            life = livesImages[0]
        } else if lives == 1 {
            life = livesImages[1]
        } else {
            life = livesImages[2]

            // run out of lives, die
            endGame(triggeredByBomb: false)
        }

        // modify contents of sprite without recreating
        life.texture = SKTexture(imageNamed: "sliceLifeGone")
        life.xScale = 1.3
        life.yScale = 1.3
        life.run(SKAction.scale(to: 1, duration: 0.1))
    }
    
    override func update(_ currentTime: TimeInterval) {
        // Called before each frame is rendered
        
        // if we have activeenemies currently and theyre below y=140
        // get off screen and remove from activeEnemies array
        if activeEnemies.count > 0 {
            // some enemies to work with
            // loop through array in reverse and pull out items
            for (index, node) in activeEnemies.enumerated().reversed() {
                if node.position.y < -140 {
                    // far bottom of screen
                    node.removeAllActions()
                    if node.name == "enemy" {
                        node.name = ""

                        // lose a life since you missed a pingu
                        subtractLife()

                        node.removeFromParent()
                        activeEnemies.remove(at: index)
                    } else if node.name == "bombContainer" {
                        node.name = ""
                        node.removeFromParent()
                        activeEnemies.remove(at: index)
                    }
                }
            }
        } else {
            if !nextSequenceQueued {
                DispatchQueue.main.asyncAfter(deadline: .now() + popupTime) {
                    [weak self] in self?.tossEnemies()
                }
                
                // dont call tossEnemies over and over
                nextSequenceQueued = true
            }
        }
        
        var bombCount = 0
        
        for node in activeEnemies {
            if node.name == "bombContainer" {
                bombCount += 1
                break
            }
        }
        
        if bombCount == 0 {
            // no bombs, stop fuse sound
            bombSoundEffect?.stop()
            bombSoundEffect = nil
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard isGameEnded == false else { return }
        guard let touch = touches.first else { return }
        
        // add wherever user touched to the slicePoints array and redraw the slice shape
        let location = touch.location(in: self)
        activeSlicePoints.append(location)
        redrawActiveSlice()
        
        // play sound only if sound isnt currently playing
        if !isSwooshSoundActive {
            playSwooshSound()
        }

        // all nodes under finger right now
        let nodesAtPoint = nodes(at: location)

        // only enter loop if node is an SKSpriteNode
        for case let node as SKSpriteNode in nodesAtPoint {
            if node.name == "enemy" {
                // destroy penguin
                if let emitter = SKEmitterNode(fileNamed: "sliceHitEnemy") {
                    emitter.position = node.position
                    addChild(emitter)
                }


                // cant keep getting score slicing it
                node.name = ""

                // stop from falling
                node.physicsBody?.isDynamic = false

                // scale/fade out
                let scaleOut = SKAction.scale(to: 0.001, duration: 0.2)
                let fadeOut = SKAction.fadeOut(withDuration: 0.2)

                // group means run actions at same time rather than sequence
                let group = SKAction.group([scaleOut, fadeOut])
                let sequence = SKAction.sequence([group, .removeFromParent()])
                node.run(sequence)

                // increment player score
                score += 1

                // find where enemy is in activeEnemies array and remove
                if let index = activeEnemies.firstIndex(of: node) {
                    activeEnemies.remove(at: index)
                }

                // play sound so we know we hit a pingu
                run(SKAction.playSoundFileNamed("whack.caf", waitForCompletion: false))
            } else if node.name == "bomb" {
                // lose game immediately if you swipe a bomb

                // destroy the bomb
                guard let bombContainer = node.parent as? SKSpriteNode else { continue }

                if let emitter = SKEmitterNode(fileNamed: "sliceHitBomb") {
                    emitter.position = bombContainer.position
                    addChild(emitter)
                }

                // cant slice more than once
                node.name = ""

                // stop from falling
                bombContainer.physicsBody?.isDynamic = false

                let scaleOut = SKAction.scale(to: 0.001, duration: 0.2)
                let fadeOut = SKAction.fadeOut(withDuration: 0.2)
                let group = SKAction.group([scaleOut, fadeOut])
                let sequence = SKAction.sequence([group, .removeFromParent()])
                bombContainer.run(sequence)

                if let index = activeEnemies.firstIndex(of: bombContainer) {
                    activeEnemies.remove(at: index)
                }

                // play explosion sound
                run(SKAction.playSoundFileNamed("explosion.caf", waitForCompletion: false))

                endGame(triggeredByBomb: true)
            }
        }
    }

    func endGame(triggeredByBomb: Bool) {
        guard isGameEnded == false else { return }

        isGameEnded = true
        physicsWorld.speed = 0

        // stop ability to tap/swipe
        isUserInteractionEnabled = false

        // stop bomb sound and destroy audio player
        bombSoundEffect?.stop()
        bombSoundEffect = nil

        if triggeredByBomb {
            for index in 0...2 {
                livesImages[index].texture = SKTexture(imageNamed: "sliceLifeGone")
            }

        }
    }
    
    func playSwooshSound() {
        // only one sound at a time
        isSwooshSoundActive = true
        
        // play 1 of 3 sounds randomly
        let randomNumber = Int.random(in: 1...3)
        let soundName = "swoosh\(randomNumber).caf"
        
        // wait until fully finished before trigger completion closure
        let swooshSound = SKAction.playSoundFileNamed(soundName, waitForCompletion: true)
        run(swooshSound) { [weak self] in
            self?.isSwooshSoundActive = false
        }
    }
    
    func redrawActiveSlice() {
        // use UIBezierPath to make curves between lines
        if activeSlicePoints.count < 2 {
            // fewer than 2 slices (0 or 1 point) we cannot draw a line
            // clear out shapes and exit method
            activeSliceBG.path = nil
            activeSliceFG.path = nil
            return
        }
        
        // track only up to 12 slice points in array, remove oldest one
        // stop swipe shapes from being too long
        if activeSlicePoints.count > 12 {
            activeSlicePoints.removeFirst(activeSlicePoints.count - 12)
        }
        
        // start drawing new path at first swipe point
        // go through each of the other points drawing lines there
        let path = UIBezierPath()
        path.move(to: activeSlicePoints[0])
        for i in 1 ..< activeSlicePoints.count {
            path.addLine(to: activeSlicePoints[i])
        }
        
        activeSliceBG.path = path.cgPath
        activeSliceFG.path = path.cgPath
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        // fade out slice shapes over 0.25s
        activeSliceBG.run(SKAction.fadeOut(withDuration: 0.25))
        activeSliceFG.run(SKAction.fadeOut(withDuration: 0.25))
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        // make sure have a touch
        guard let touch = touches.first else { return }
        
        // new touch, remove all points in activeSlicePoints array
        activeSlicePoints.removeAll(keepingCapacity: true)
        
        // add current touch location to acticeSlicePoints array
        let location = touch.location(in: self)
        activeSlicePoints.append(location)
        
        // update SKShapeNode as needed on screen
        redrawActiveSlice()
        
        // when touchesEnded is called, we remove these nodes from the screen via alpha = 0
        // if we stop touching and start touching again immediately afterwards, fadeout will
        // still be running. FIRST we *MUST* remove all actions to cancel the fade out.
        activeSliceBG.removeAllActions()
        activeSliceFG.removeAllActions()
        
        activeSliceBG.alpha = 1
        activeSliceFG.alpha = 1
    }
    
    func createEnemy(forceBomb: ForceBomb = .random) {
        // by default most of the game mode will be random choice of enemy or bomb
        
        let enemy: SKSpriteNode
        var enemyType = Int.random(in: 0...6)
        
        if forceBomb == .never {
            // def not a bomb
            enemyType = 1
        } else if forceBomb == .always {
            enemyType = 0 // bomb
        }
        
        if enemyType == 0 {
            // make bomb
            enemy = SKSpriteNode()
            enemy.zPosition = 1
            enemy.name = "bombContainer"
            
            let bombImage = SKSpriteNode(imageNamed: "sliceBomb")
            bombImage.name = "bomb"
            enemy.addChild(bombImage) // add bomb to container

            if bombSoundEffect != nil {
                // make certain bomb sound effect stops every single time (play from scratch every time)
                bombSoundEffect?.stop()
                bombSoundEffect = nil
            }
            
            if let path = Bundle.main.url(forResource: "sliceBombFuse", withExtension: "caf") {
                // find sound file in bundle
                if let sound = try? AVAudioPlayer(contentsOf: path) {
                    bombSoundEffect = sound
                    sound.play()
                }
            }
            
            // for sure succeeded, show emitter node behind bomb
            if let emitter = SKEmitterNode(fileNamed: "sliceFuse") {
                emitter.position = CGPoint(x: 76, y: 64)
                enemy.addChild(emitter)
                
            }
            
        } else {
            // penguin
            enemy = SKSpriteNode(imageNamed: "penguin")
            run(SKAction.playSoundFileNamed("launch.caf", waitForCompletion: false))
            enemy.name = "enemy" // know if its sliced a penguin
        }
        
        // give enemy position off bottom edge of screen
        // give random angular velocity (spin)
        // random x velocity
        // random y velocity to fly at different speed
        // give circular physics body
        // collisionBitMask = 0 so they dont collide
        let randomPosition = CGPoint(x: Int.random(in: 64...960), y: -128)
        enemy.position = randomPosition
        
        let randomAngularVelocity = CGFloat.random(in: -3...3)
        let randomXVelocity: Int
        
        if randomPosition.x < 256 {
            // way to left of screen
            // make x veloicty high to move right dramaically
            randomXVelocity = Int.random(in: 8...15)
        } else if randomPosition.x < 512 {
            // left side of screen, not extreme left; move to right gently
            randomXVelocity = Int.random(in: 3...5)
        } else if randomPosition.x < 768 {
            // right but not extreme right; moves to left gently
            randomXVelocity = -Int.random(in: 3...5)
        } else {
            // far right of screen to left very quickly
            randomXVelocity = -Int.random(in: 8...15)
        }
        
        let randomYVelocity = Int.random(in: 24...32)
        
        enemy.physicsBody = SKPhysicsBody(circleOfRadius: 64) // half size of sprites
        enemy.physicsBody?.velocity = CGVector(dx: randomXVelocity * 40, dy: randomYVelocity * 40)
        enemy.physicsBody?.angularVelocity = randomAngularVelocity
        enemy.physicsBody?.collisionBitMask = 0 // bounce off nothing in the game
        
        
        addChild(enemy)
        activeEnemies.append(enemy)
    }
    
    func tossEnemies() {
        guard isGameEnded == false else { return }

        // decrease popupTime and chainDelay by a small amount so game gets harder as you play longer
        // increase speed of physics world over time as well
        popupTime *= 0.991
        chainDelay *= 0.99
        physicsWorld.speed *= 1.02
        
        // read current seq position from sequence array and create enemies a few ways
        let sequenceType = sequence[sequencePosition]
        switch sequenceType {
        case .oneNoBomb:
            // beginning of game, no bomb
            createEnemy(forceBomb: .never)
        case .one:
            createEnemy()
        case .twoWithOneBomb:
            // one bomb, one not bomb
            createEnemy(forceBomb: .never)
            createEnemy(forceBomb: .always)
        case .two:
            createEnemy()
            createEnemy()
        case .three:
            createEnemy()
            createEnemy()
            createEnemy()
        case .four:
            createEnemy()
            createEnemy()
            createEnemy()
            createEnemy()
        case .chain:
            // 1 enemy straight away
            createEnemy()
            
            // use dispatchqueue to create enemy after some delay has passed (1/5 of our chainDelay)
            DispatchQueue.main.asyncAfter(deadline: .now() + (chainDelay / 5.0)) {
                [weak self] in self?.createEnemy()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + (chainDelay / 5.0 * 2)) {
                [weak self] in self?.createEnemy()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + (chainDelay / 5.0 * 3)) {
                [weak self] in self?.createEnemy()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + (chainDelay / 5.0 * 4)) {
                [weak self] in self?.createEnemy()
            }
            
        case .fastChain:
            // 1 enemy straight away
            createEnemy()
            
            // use dispatchqueue to create enemy after some delay has passed (1/5 of our chainDelay)
            DispatchQueue.main.asyncAfter(deadline: .now() + (chainDelay / 10.0)) {
                [weak self] in self?.createEnemy()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + (chainDelay / 10.0 * 2)) {
                [weak self] in self?.createEnemy()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + (chainDelay / 10.0 * 3)) {
                [weak self] in self?.createEnemy()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + (chainDelay / 10.0 * 4)) {
                [weak self] in self?.createEnemy()
            }
        }
        sequencePosition += 1
        
        // dont have a call to toss enemies in pipeline waiting to execute
        // set to true when gap to previous sequence item finishing and tossEnemies being called
        // i know there arent enemies right now but more will come shortly
        nextSequenceQueued = false
        
    }
}
