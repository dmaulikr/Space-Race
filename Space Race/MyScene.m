//
//  GameScene.m
//  Space Race
//
//  Created by Andy Zimmelman on 4/8/15.
//  Copyright (c) 2015 Andy Zimmelman. All rights reserved.
//

#import "MyScene.h"

@interface MyScene () <SKPhysicsContactDelegate> {
    SKSpriteNode* _player;
    SKColor* _bgColor;
    SKTexture* _beamTexture1;
    SKTexture* _beamTexture2;
    SKAction* _moveAndRemoveBeams;
    SKNode* _beams;
    SKNode* _moving;
    BOOL _canRestart;
    SKLabelNode* _scoreLabel;
    NSInteger _score;
    
}
@end


@implementation MyScene

static const uint32_t playerCategory = 1 << 0;
static const uint32_t worldCategory = 1 << 1;
static const uint32_t asteroidCategory = 1 << 2;
static const uint32_t scoreCategory = 1 << 3;

static NSInteger const asteroidGap = 100;

-(id)initWithSize:(CGSize)size {
    if (self = [super initWithSize:size]) {
        /* Setup your scene here */
       [self runAction:[SKAction repeatActionForever:[SKAction playSoundFileNamed:@"SPACEJAM.mp3" waitForCompletion:YES]]]; 
        _canRestart = NO;
        
        //sets gravity to half and contact delegate for physics world to self
        self.physicsWorld.gravity = CGVectorMake( 0.0, -5.0 );
        self.physicsWorld.contactDelegate = self;
        
        //sets background color to black
        _bgColor =  [UIColor colorWithPatternImage:[UIImage imageNamed:@"starBG.png"]];
        [self setBackgroundColor:_bgColor];
        
        //moving node
        _moving = [SKNode node];
        [self addChild:_moving];
        
        //beams node
        _beams = [SKNode node];
        [_moving addChild:_beams];
        
        //sets up texture for the player
        SKTexture* playerTexture = [SKTexture textureWithImageNamed:@"spaceShipPlayer.png"];
        playerTexture.filteringMode = SKTextureFilteringNearest;
        
        _player = [SKSpriteNode spriteNodeWithTexture:playerTexture];
        [_player setScale:1.0];
        _player.position = CGPointMake(self.frame.size.width / 4, CGRectGetMidY(self.frame));
        _player.physicsBody = [SKPhysicsBody bodyWithCircleOfRadius:_player.size.height / 2];
        _player.physicsBody.dynamic = YES;
        _player.physicsBody.allowsRotation = NO;
        _player.physicsBody.categoryBitMask = playerCategory;
        _player.physicsBody.collisionBitMask = worldCategory | asteroidCategory;
        _player.physicsBody.contactTestBitMask = worldCategory | asteroidCategory;
        
        [self addChild:_player];

        // Creates moonground
        
        SKTexture* groundTexture = [SKTexture textureWithImageNamed:@"ground.png"];
        groundTexture.filteringMode = SKTextureFilteringNearest;
        
        SKAction* moveGroundSprite = [SKAction moveByX:-groundTexture.size.width*2 y:0 duration:0.02 * groundTexture.size.width*2];
        SKAction* resetGroundSprite = [SKAction moveByX:groundTexture.size.width*2 y:0 duration:0];
        SKAction* moveGroundSpritesForever = [SKAction repeatActionForever:[SKAction sequence:@[moveGroundSprite, resetGroundSprite]]];
        
        for( int i = 0; i < 2 + self.frame.size.width / ( groundTexture.size.width * 2 ); ++i ) {
            // Create the sprite
            SKSpriteNode* sprite = [SKSpriteNode spriteNodeWithTexture:groundTexture];
            [sprite setScale:2.0];
            sprite.position = CGPointMake(i * sprite.size.width, sprite.size.height / 2);
            [sprite runAction:moveGroundSpritesForever];
            [_moving addChild:sprite];
        }
        // Create asteroidBelt
        
        SKTexture* asteroidTexture = [SKTexture textureWithImageNamed:@"asteroidBelt.png"];
        asteroidTexture.filteringMode = SKTextureFilteringNearest;
        
        SKAction* moveAsteroidSprite = [SKAction moveByX:-asteroidTexture.size.width*2 y:0 duration:0.1 * asteroidTexture.size.width*2];
        SKAction* resetAsteroidSprite = [SKAction moveByX:asteroidTexture.size.width*2 y:0 duration:0];
        SKAction* moveAsteroidSpritesForever = [SKAction repeatActionForever:[SKAction sequence:@[moveAsteroidSprite, resetAsteroidSprite]]];
        
        for( int i = 0; i < 2 + self.frame.size.width / ( asteroidTexture.size.width * 2 ); ++i ) {
            SKSpriteNode* sprite = [SKSpriteNode spriteNodeWithTexture:asteroidTexture];
            [sprite setScale:2.0];
            sprite.zPosition = -20;
            sprite.position = CGPointMake(i * sprite.size.width, sprite.size.height / 2 + groundTexture.size.height * 2);
            [sprite runAction:moveAsteroidSpritesForever];
            [_moving addChild:sprite];
        }
        // Create ground so when collision occurs, player dies
        
        SKNode* dummy = [SKNode node];
        dummy.position = CGPointMake(0, groundTexture.size.height);
        dummy.physicsBody = [SKPhysicsBody bodyWithRectangleOfSize:CGSizeMake(self.frame.size.width, groundTexture.size.height * 2)];
        dummy.physicsBody.dynamic = NO;
        dummy.physicsBody.categoryBitMask = worldCategory;
        [self addChild:dummy];
        
        // Create beams
        
        _beamTexture1 = [SKTexture textureWithImageNamed:@"rightSideUp.png"];
        _beamTexture1.filteringMode = SKTextureFilteringNearest;
        _beamTexture2 = [SKTexture textureWithImageNamed:@"upSideDown.png"];
        _beamTexture2.filteringMode = SKTextureFilteringNearest;
        
        CGFloat distanceToMove = self.frame.size.width + 2 * _beamTexture1.size.width;
        SKAction* moveBeams = [SKAction moveByX:-distanceToMove y:0 duration:0.01 * distanceToMove];
        SKAction* removeBeams = [SKAction removeFromParent];
        _moveAndRemoveBeams= [SKAction sequence:@[moveBeams, removeBeams]];
        
        SKAction* spawn = [SKAction performSelector:@selector(spawnBeams) onTarget:self];
        SKAction* delay = [SKAction waitForDuration:2.0];
        SKAction* spawnThenDelay = [SKAction sequence:@[spawn, delay]];
        SKAction* spawnThenDelayForever = [SKAction repeatActionForever:spawnThenDelay];
        [self runAction:spawnThenDelayForever];
        
        // Initialize label and create a label which holds the score
        _score = 0;
        _scoreLabel = [SKLabelNode labelNodeWithFontNamed:@"MarkerFelt-Wide"];
        _scoreLabel.position = CGPointMake( CGRectGetMidX( self.frame ), 3 * self.frame.size.height / 4 );
        _scoreLabel.zPosition = 100;
        _scoreLabel.text = [NSString stringWithFormat:@"%ld", (long)_score];
        [self addChild:_scoreLabel];
    }
    return self;
}
-(void)spawnBeams {
    
    //creates a function for beams to respawn
    SKNode* beamPair = [SKNode node];
    beamPair.position = CGPointMake( self.frame.size.width + _beamTexture1.size.width, 0 );
    beamPair.zPosition = -10;
    
    CGFloat y = arc4random() % (NSInteger)( self.frame.size.height / 3 );
    
    SKSpriteNode* beam1 = [SKSpriteNode spriteNodeWithTexture:_beamTexture1];
    [beam1 setScale:2.0];
    beam1.position = CGPointMake( 0, y );
    beam1.physicsBody = [SKPhysicsBody bodyWithRectangleOfSize:beam1.size];
    beam1.physicsBody.dynamic = NO;
    beam1.physicsBody.categoryBitMask = asteroidCategory;
    beam1.physicsBody.contactTestBitMask = playerCategory;
    
    [beamPair addChild:beam1];
    
    SKSpriteNode* beam2 = [SKSpriteNode spriteNodeWithTexture:_beamTexture2];
    [beam2 setScale:2.0];
    beam2.position = CGPointMake( 0, y + beam1.size.height + asteroidGap );
    beam2.physicsBody = [SKPhysicsBody bodyWithRectangleOfSize:beam2.size];
    beam2.physicsBody.dynamic = NO;
    beam2.physicsBody.categoryBitMask = asteroidCategory;
    beam2.physicsBody.contactTestBitMask = playerCategory;
    [beamPair addChild:beam2];
    
    //creates contact node for asteroidbeams
    SKNode* contactNode = [SKNode node];
    contactNode.position = CGPointMake( beam1.size.width + _player.size.width / 2, CGRectGetMidY( self.frame ) );
    contactNode.physicsBody = [SKPhysicsBody bodyWithRectangleOfSize:CGSizeMake(beam2.size.width, self.frame.size.height)];
    contactNode.physicsBody.dynamic = NO;
    contactNode.physicsBody.categoryBitMask = scoreCategory;
    contactNode.physicsBody.contactTestBitMask = playerCategory;
    [beamPair addChild:contactNode];
    
    [beamPair runAction:_moveAndRemoveBeams];
    
    [_beams addChild:beamPair];
}

-(void)resetScene {
    // Reset players properties
    _player.position = CGPointMake(self.frame.size.width / 4, CGRectGetMidY(self.frame));
    _player.physicsBody.velocity = CGVectorMake( 0, 0 );
    _player.physicsBody.collisionBitMask = worldCategory | asteroidCategory;
    _player.speed = 1.0;
    _player.zRotation = 0.0;
    
    // Remove all existing pipes
    [_beams removeAllChildren];
    
    // Reset _canRestart
    _canRestart = NO;
    
    // Restart animation
    _moving.speed = 1;
    
    // Reset score
    _score = 0;
    _scoreLabel.text = [NSString stringWithFormat:@"%ld", (long)_score];
}
-(void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    /* Called when a touch begins */
    if( _moving.speed > 0 ) {
        _player.physicsBody.velocity = CGVectorMake(0, 0);
        [_player.physicsBody applyImpulse:CGVectorMake(0, 8)];
    } else if( _canRestart ) {
        [self resetScene];
    }
}
CGFloat clamp(CGFloat min, CGFloat max, CGFloat value) {
    if( value > max ) {
        return max;
    } else if( value < min ) {
        return min;
    } else {
        return value;
    }
}

-(void)update:(CFTimeInterval)currentTime {
    /* Called before each frame is rendered */
    if( _moving.speed > 0 ) {
        _player.zRotation = clamp( -1, 0.5, _player.physicsBody.velocity.dy * ( _player.physicsBody.velocity.dy < 0 ? 0.003 : 0.001 ) );
    }
}

- (void)didBeginContact:(SKPhysicsContact *)contact {
    if( _moving.speed > 0 ) {
        if( ( contact.bodyA.categoryBitMask & scoreCategory ) == scoreCategory || ( contact.bodyB.categoryBitMask & scoreCategory ) == scoreCategory ) {
            // player has contact with score entity
            
            _score++;
            _scoreLabel.text = [NSString stringWithFormat:@"%ld", (long)_score];
            
            // Add a little visual feedback for the score increment
            [_scoreLabel runAction:[SKAction sequence:@[[SKAction scaleTo:1.5 duration:0.1], [SKAction scaleTo:1.0 duration:0.1]]]];
        } else {
            // player has collided with world
            
            _moving.speed = 0;
            
            _player.physicsBody.collisionBitMask = worldCategory;
            
            [_player runAction:[SKAction rotateByAngle:M_PI * _player.position.y * 0.01 duration:_player.position.y * 0.003] completion:^{
                _player.speed = 0;
            }];
            
            // Flash background if contact is detected
            [self removeActionForKey:@"flash"];
            [self runAction:[SKAction sequence:@[[SKAction repeatAction:[SKAction sequence:@[[SKAction runBlock:^{
                self.backgroundColor = [SKColor redColor];
            }], [SKAction waitForDuration:0.05], [SKAction runBlock:^{
                self.backgroundColor = _bgColor;
            }], [SKAction waitForDuration:0.05]]] count:4], [SKAction runBlock:^{
                _canRestart = YES;
            }]]] withKey:@"flash"];
        }
    }
}


@end
