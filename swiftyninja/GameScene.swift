//
//  GameScene.swift
//  swiftyninja
//
//  Created by iMac on 6/3/20.
//  Copyright © 2020 Lord Nibbler. All rights reserved.
//

import SpriteKit

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
    
    override func didMove(to view: SKView) {
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
        createScore()
        createLives()
        createSlices()
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
        // create 3 SKSpriteNode and position at top left corner of screen
        // add to life images array to show if they have a life while they play
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
    
    
    override func update(_ currentTime: TimeInterval) {
        // Called before each frame is rendered
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        
        // add wherever user touched to the slicePoints array and redraw the slice shape
        let location = touch.location(in: self)
        activeSlicePoints.append(location)
        redrawActiveSlice()
        
        // play sound only if sound isnt currently playing
        if !isSwooshSoundActive {
            playSwooshSound()
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
}
