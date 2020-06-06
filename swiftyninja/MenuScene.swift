//
//  MenuScene.swift
//  swiftyninja
//
//  Created by iMac on 6/5/20.
//  Copyright © 2020 Lord Nibbler. All rights reserved.
//

import SpriteKit

class MenuScene: SKScene {
    var newGameButton: SKSpriteNode?
    var highScoreLabel: SKLabelNode?
    
    override func didMove(to view: SKView) {
        newGameButton = self.childNode(withName: "newGameButton") as? SKSpriteNode
        highScoreLabel = self.childNode(withName: "highScoreLabel") as? SKLabelNode

        // read high score
        let userDefaults = UserDefaults.standard
        let highScore = userDefaults.integer(forKey: "highScore")
        highScoreLabel?.text = "High Score: \(highScore)"
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        
        let location = touch.location(in: self)
        let nodesArray = self.nodes(at: location)
        if nodesArray.first?.name == "newGameButton" {
            let transition = SKTransition.flipHorizontal(withDuration: 0.5)
            let gameScene = SKScene(fileNamed: "GameScene") as! GameScene
            gameScene.scaleMode = .fill
            self.view?.presentScene(gameScene, transition: transition)
        }
    }
}
