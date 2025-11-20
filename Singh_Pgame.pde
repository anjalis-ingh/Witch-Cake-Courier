// Witch Cake Courier Game - Anjali Singh

// IMPORTS
// sound effects + bgm
import processing.sound.*; 

// ASSET FILENAMES  
// backgrounds
final String BG1_FILE = "1.png";
final String BG2_FILE = "2.png";
final String BG3_FILE = "3.png";

// character + houses
final String WITCH_FILE = "witch.png";
final String HOUSE_STRAW_FILE = "straw-house.png";
final String HOUSE_TREE_FILE = "tree-house.png";
final String HOUSE_WOOD_FILE = "wooden-house.png";

// cakes 
final String CAKE_CARROT_FILE = "Carrot_Cake.png";
final String CAKE_FRUIT_FILE = "Fruit_Cake.png";
final String CAKE_REDVELVET_FILE = "RedVelvet_Cake.png";

// heart icon
final String HEART_FILE = "heart.png";

// audios 
final String SFX_CORRECT_FILE = "correct.wav";
final String SFX_WRONG_FILE = "wrong.wav";
final String BGM_FILE = "bgm.mp3";

// ENUMS
// state machine for the main loop flow
enum GameState { MENU, PLAYING, WIN, LOSE }

// types of cakes the player can drop
enum CakeType  { CARROT, FRUIT, REDVELVET }

// the outcome of a delivery attempt when a cake lands
enum DeliveryResult { CORRECT, WRONG, IGNORED }

// GLOBALS
// images 
PImage bg1, bg2, bg3;
PImage witchImg, houseStrawImg, houseTreeImg, houseWoodImg;
PImage carrotImg, fruitImg, redvelvetImg, heartImg;

// sounds
SoundFile sfxCorrect, sfxWrong, bgm;

// game state 
// ensures the level 1 menu overlay only shows once
boolean introShown = false;
// 0..2 for 3 levels
int levelIndex = 0;             
GameState state = GameState.MENU;

// character 
Witch witch;           
// active falling cakes
ArrayList<Cake> cakes = new ArrayList<Cake>(); 
// encapsulates timer, houses, orders for this level
Level currentLevel;             

// scrolling world
// for looping background 
float bgScrollX = 0;           
// base horizontal scroll speed
float bgScrollSpeed = 3.0;     
// applied to houses to make them move left across screen
float worldOffset = 0;          

// score
int score = 0;
// points per correct delivery
final int SCORE_HIT = 100;  
// points lost per wrong delivery
final int SCORE_MISS = 25;    
// per-second bonus when finishing a level
final int SCORE_TBONUS = 5;     

// ui buttons (top-right) to drop specific cakes by mouse
Button carrotBtn, fruitBtn, redBtn;

// big red X at top for wrong drop
int wrongFlashTimer = 0;
final int WRONG_FLASH_DURATION = 25;

// house spawn pacing
final int MIN_SPAWN_SEC = 1;
final int MAX_SPAWN_SEC = 2;
// horizontal gap in world units between spawns
final int MIN_SPAWN_GAP_PX = 320;   
// just to prevent clutter
final int MAX_ONSCREEN_HOUSES = 3;  

// per-level speed scaling
// background scroll
final float BASE_BG_SPEED = 5.0, BG_SPEED_INC = 2.0;     
// player arrow speed
final float BASE_KEY_SPEED = 8.0, KEY_SPEED_INC = 2.0;  
// passive drift X
final float BASE_DRIFT_X = 0.3, DRIFT_X_INC = 0.08;  
// passive drift Y
final float BASE_DRIFT_Y = 0.15, DRIFT_Y_INC = 0.04;   

// HUD (heads-up display) + button layout
final int HUD_MARGIN = 6;
final int HUD_PAD = 10;
final int BTN_SIZE = 56;
final int BTN_PAD = 10;

// HELPERS
// map a cake type to its image
PImage getCakeImage(CakeType t) {
  if (t == CakeType.CARROT) {
    return carrotImg;
  } else if (t == CakeType.FRUIT) {
    return fruitImg;
  } else {
    return redvelvetImg;
  }
}

// choose which preloaded house image to use based on filename
PImage chooseHouseSprite(String file) {
  if (file.equals(HOUSE_STRAW_FILE)) {
    return houseStrawImg;
  }
  if (file.equals(HOUSE_TREE_FILE)) {  
    return houseTreeImg;
  }
  return houseWoodImg;
}

// sound helpers
void playCorrect() { 
  if (sfxCorrect != null) {
    sfxCorrect.play(); 
  }
}

void playWrong() { 
  if (sfxWrong != null) {
    sfxWrong.play();   
  }
}

// full-screen darkener overlay
void drawDimOverlay(int alpha) {
  pushStyle();
  fill(0, alpha);
  noStroke();
  rect(0, 0, width, height);
  popStyle();
}

// reusable rounded translucent panel
void drawPanel(int x, int y, int w, int h, int r, int alpha) {
  pushStyle();
  fill(255, alpha);
  noStroke();
  rect(x, y, w, h, r);
  popStyle();
}

// small rounded chip at the very top-center (used for level x)
void drawTopCenterBadge(String text) {
  pushStyle();
  textSize(18);
  float tw = textWidth(text) + 24;
  noStroke();
  fill(0, 120);
  rectMode(CENTER);
  rect(width/2, 18, tw, 28, 12);
  fill(255);
  textAlign(CENTER, CENTER);
  text(text, width/2, 18);
  popStyle();
}

// CLASSES
// describes what single house to place at x with a sprite + cake request
class HouseSpec {
  String spriteFile;
  CakeType request;
  // center x (in screen/world coords used when building levels)
  float x; 
  
  HouseSpec(String spriteFile, CakeType request, float x) {
    this.spriteFile = spriteFile;
    this.request = request;
    this.x = x;
  }
}

// per-level configuration: background image, timer, house specs, and totals required
class LevelConfig {
  String bgFile;
  int timeLimitSec;
  HouseSpec[] houses;
  int needCarrot, needFruit, needRed;
  
  LevelConfig(String bgFile, int timeLimitSec, HouseSpec[] houses, int needCarrot, int needFruit, int needRed) {
    this.bgFile = bgFile;
    this.timeLimitSec = timeLimitSec;
    this.houses = houses;
    this.needCarrot = needCarrot;
    this.needFruit = needFruit;
    this.needRed = needRed;
  }
}

// three levels (houses spawn dynamically)
LevelConfig[] LEVEL_CONFIG = new LevelConfig[] {
  new LevelConfig(BG1_FILE, 60, new HouseSpec[]{}, 1, 1, 0),
  new LevelConfig(BG2_FILE, 50, new HouseSpec[]{}, 2, 1, 1),
  new LevelConfig(BG3_FILE, 40, new HouseSpec[]{}, 2, 2, 2)
};

// SETUP
void setup() {
  size(960, 540);
  surface.setTitle("Witch Cake Courier");

  // load images 
  bg1 = loadImage(BG1_FILE);
  bg2 = loadImage(BG2_FILE);
  bg3 = loadImage(BG3_FILE);

  witchImg = loadImage(WITCH_FILE);
  houseStrawImg = loadImage(HOUSE_STRAW_FILE);
  houseTreeImg = loadImage(HOUSE_TREE_FILE);
  houseWoodImg = loadImage(HOUSE_WOOD_FILE);

  carrotImg = loadImage(CAKE_CARROT_FILE);
  fruitImg = loadImage(CAKE_FRUIT_FILE);
  redvelvetImg = loadImage(CAKE_REDVELVET_FILE);

  heartImg = loadImage(HEART_FILE);

  // load sounds
  try { 
    sfxCorrect = new SoundFile(this, SFX_CORRECT_FILE); 
  } catch(Exception e) {}
  
  try { 
    sfxWrong   = new SoundFile(this, SFX_WRONG_FILE);   
  } catch(Exception e) {}
  
  try {
    bgm = new SoundFile(this, BGM_FILE);
    bgm.loop();
    bgm.amp(0.35);
  } catch(Exception e) {}

  // ui buttons for cakes (top-right stack)
  carrotBtn = new Button(width - (BTN_SIZE + BTN_PAD), BTN_PAD, BTN_SIZE, BTN_SIZE, CakeType.CARROT);
  fruitBtn = new Button(width - (BTN_SIZE + BTN_PAD), BTN_PAD*2 + BTN_SIZE, BTN_SIZE, BTN_SIZE, CakeType.FRUIT);
  redBtn = new Button(width - (BTN_SIZE + BTN_PAD), BTN_PAD*3 + BTN_SIZE*2, BTN_SIZE, BTN_SIZE, CakeType.REDVELVET);

  // initialize level 1 and display menu overlay screen
  startGame(); 
}

// GAME FLOW
// eeset to Level 1 and go to menu overlay state
void startGame() {
  levelIndex = 0;
  score = 0;
  loadLevel(levelIndex);
  // so that level 1 shows the info overlay once
  introShown = false;          
  state = GameState.MENU;
}

// build a level from LEVEL_CONFIG[idx]: set bg, house list, timer, speeds.
void loadLevel(int idx) {
  LevelConfig cfg = LEVEL_CONFIG[idx];
  PImage bg;

  if (cfg.bgFile.equals(BG1_FILE)) {
    bg = bg1;
  } 
  else if (cfg.bgFile.equals(BG2_FILE)) {
    bg = bg2;
  } 
  else {
    bg = bg3;
  }

  // build initial houses from config 
  ArrayList<House> houses = new ArrayList<House>();
  for (int i = 0; i < cfg.houses.length; i++) {
    HouseSpec hs = cfg.houses[i];
    PImage sprite = chooseHouseSprite(hs.spriteFile);
    houses.add(new House(hs.x, height - sprite.height/2, sprite, hs.request));
  }

  // create level object (timer + order counts + spawn system)
  currentLevel = new Level(bg, houses, cfg.timeLimitSec, cfg.needCarrot, cfg.needFruit, cfg.needRed);

  // witch spawn point
  witch = new Witch(120, height * 0.35);

  // clear any old falling cakes
  cakes.clear();

  // reset scrolling background + world offset
  bgScrollX = 0;
  worldOffset = 0;

  // per-level speed scaling (harder each level)
  bgScrollSpeed = BASE_BG_SPEED + idx * BG_SPEED_INC;
  witch.speed  = BASE_KEY_SPEED + idx * KEY_SPEED_INC;
  witch.driftX = BASE_DRIFT_X + idx * DRIFT_X_INC;
  witch.driftY = BASE_DRIFT_Y + idx * DRIFT_Y_INC;
}

// DRAW
void draw() {
  background(15);

  // background scroll updates every frame
  // worldOffset moves houses left
  bgScrollX += bgScrollSpeed;
  if (bgScrollX >= width) {
    bgScrollX -= width;
  }
  worldOffset -= bgScrollSpeed;

  drawScrollingBackground(currentLevel.bg);

  // state machine 
  switch(state) {
    case MENU:
      drawHUD();               
      drawWitchAndCakes();
      drawHouses();
      if (!introShown) {
        // instructions only once at Level 1
        drawMenuOverlay();     
      } 
      else {
        // safety fallback if introShown got out of sync
        state = GameState.PLAYING; 
      }
      break;

    case PLAYING:
      // physics, timer, spawns, collisions
      updateGame();            
      drawHUD();
      drawWitchAndCakes();
      drawHouses();
      // flashing red X when a wrong drop happens
      drawWrongFlash();        
      break;

    case WIN:
      drawHUD();
      drawWitchAndCakes();
      drawHouses();
      drawWinOverlay();
      break;

    case LOSE:
      drawHUD();
      drawWitchAndCakes();
      drawHouses();
      drawLoseOverlay();
      break;
  }
}

// draw a horizontally tiled background that loops seamlessly
void drawScrollingBackground(PImage bg) {
  pushStyle();
  imageMode(CORNER);
  noTint();
  // scale background to full canvas width
  int tileW = width;       
  // where to start the first tile
  int startX = -(int)bgScrollX;      
  
  image(bg, startX, 0, tileW, height);
  image(bg, startX + tileW, 0, tileW, height);
  image(bg, startX + 2*tileW, 0, tileW, height); 
  popStyle();
}

// GAME UPDATE
// game logic: timer, player motion, cake falling, spawns, win/lose
void updateGame() {
  // timer & lose condition
  currentLevel.updateTimer();
  if (currentLevel.timeLeft <= 0) {
    state = GameState.LOSE;
    return;
  }

  // witch motion (passive drift + arrow key control)
  witch.applyDrift(0.06, 0.02);
  witch.handleInput();
  witch.update();

  // cakes falling + landing check
  for (int i = cakes.size()-1; i >= 0; i--) {
    Cake c = cakes.get(i);
    c.update();
    if (c.pos.y >= currentLevel.groundY()) {
      // decide correct, wrong, or ignored 
      DeliveryResult res = attemptDelivery(c); 
      c.landed = true;
      cakes.remove(i);
      
      if (res == DeliveryResult.WRONG) {
        // show a brief red X
        wrongFlashTimer = WRONG_FLASH_DURATION; 
      }
    }
  }

  // level complete --> add time bonus, then advance or win
  if (currentLevel.allOrdersComplete()) {
    score += currentLevel.timeLeft * SCORE_TBONUS;
    
    if (levelIndex < LEVEL_CONFIG.length - 1) {
      levelIndex++;
      loadLevel(levelIndex);
      state = GameState.PLAYING;
    } 
    else {
      state = GameState.WIN;
    }
  }

  // spawn houses as needed
  currentLevel.maybeSpawnHouse();

  // clean up houses that have scrolled far off the left
  for (int i = currentLevel.houses.size()-1; i >= 0; i--) {
    House h = currentLevel.houses.get(i);
    float screenX = h.x + worldOffset;
    if (screenX < -h.sprite.width - 80) {
      currentLevel.houses.remove(i);
    }
  }
}

// decide the outcome when a cake hits the ground line
DeliveryResult attemptDelivery(Cake c) {
  // find a house whose roof lies directly under cake's x-position
  House target = currentLevel.houseDirectlyBelow(c.pos.x);
  if (target == null) {
    playWrong();
    score -= SCORE_MISS;
    // dropped in empty space
    return DeliveryResult.WRONG; 
  }

  // if house already has cake delivered, ignore (no penalty)
  if (target.satisfied) {
    return DeliveryResult.IGNORED;
  }

  // if the global need for this house's request is zero, it's wrong now (late)
  if (!currentLevel.needs(target.request)) {
    playWrong();
    score -= SCORE_MISS;
    return DeliveryResult.WRONG;
  }

  // cake type check: correct cake --> decrement global order + celebrate + score
  if (target.request == c.type) {
    currentLevel.decrementOrder(c.type);
    target.celebrate();
    playCorrect();
    score += SCORE_HIT;
    return DeliveryResult.CORRECT;
  } 
  else {
    // Wwong cake type for this house
    playWrong();
    score -= SCORE_MISS;
    return DeliveryResult.WRONG;
  }
}

// RENDER ASSETS
// draw player + all active cakes
void drawWitchAndCakes() {
  for (int i = 0; i < cakes.size(); i++) {
    Cake c = cakes.get(i);
    c.draw();
  }
  witch.draw();
}

// draw all active houses (with cake request icon + celebration heart when satisfied_
void drawHouses() {
  for (int i = 0; i < currentLevel.houses.size(); i++) {
    House h = currentLevel.houses.get(i);
    h.draw();
  }
}

// HUD includes level chip, timer, score, remaining orders, and cake buttons + hotkeys
void drawHUD() {
  // top-center level chip
  drawTopCenterBadge("Level " + (levelIndex + 1));

  textAlign(LEFT, TOP);
  textSize(16);

  String timerStr = "Time: " + nf(currentLevel.timeLeft, 2);
  String scoreStr = "Score: " + score;

  float timerW = textWidth(timerStr);
  float scoreW = textWidth(scoreStr);

  // find widest order text so the box width fits the largest number
  float carrotW = textWidth("x " + currentLevel.needCarrot);
  float fruitW = textWidth("x " + currentLevel.needFruit);
  float redW = textWidth("x " + currentLevel.needRed);
  float orderTextW = max(carrotW, max(fruitW, redW));
  float iconRowW = 28 + 6 + orderTextW;

  float contentW = max(max(timerW, scoreW), iconRowW);
  float boxW = HUD_PAD*2 + contentW;
  
  // format: time, gap, score, gap, orders
  float boxH = HUD_PAD*2 + 16 + 4 + 16 + 8 + 3*32;

  // draw translucent panel
  drawPanel(HUD_MARGIN, HUD_MARGIN, (int)boxW, (int)boxH, 8, 60);

  float cx = HUD_MARGIN + HUD_PAD;
  float cy = HUD_MARGIN + HUD_PAD;

  // timer + score
  fill(0);
  text(timerStr, cx, cy); 
  cy += 16 + 4;
  text(scoreStr, cx, cy); 
  cy += 16 + 8;

  // remaining order counts with small icons
  imageMode(CORNER);
  image(carrotImg, cx, cy, 28, 28); 
  text("x " + currentLevel.needCarrot, cx + 28 + 6, cy + 6); 
  cy += 32;
  
  image(fruitImg,  cx, cy, 28, 28); 
  text("x " + currentLevel.needFruit,  cx + 28 + 6, cy + 6); 
  cy += 32;
  
  image(redvelvetImg, cx, cy, 28, 28); 
  text("x " + currentLevel.needRed,  cx + 28 + 6, cy + 6);

  // top-right cake buttons + numeric labels for hotkeys
  carrotBtn.draw(carrotImg);
  fruitBtn.draw(fruitImg);
  redBtn.draw(redvelvetImg);

  fill(255);
  textAlign(LEFT, CENTER);
  textSize(18);
  text("1", carrotBtn.x - 18, carrotBtn.y + carrotBtn.h/2);
  text("2", fruitBtn.x - 18, fruitBtn.y + fruitBtn.h/2);
  text("3", redBtn.x - 18, redBtn.y + redBtn.h/2);
}

// one-time how to play menu overlay (only on first level)
void drawMenuOverlay() {
  drawDimOverlay(180);

  // centered panel
  int panelW = min(560, width - 60);
  int panelH = 330;
  int px = (width - panelW) / 2;
  int py = (height - panelH) / 2;

  drawPanel(px, py, panelW, panelH, 12, 240);

  // title
  fill(20);
  textAlign(LEFT, TOP);
  textSize(26);
  text("Welcome to Witch Cake Courier!", px + 18, py + 22);

  // body text 
  fill(30);
  textSize(15);
  float x = px + 18, y = py + 75, lh = 22;

  text("Goal: Deliver the right cakes before time runs out", x, y); y += lh * 1.5;
  text("The top-left box tells you the time left and remaining cake orders", x, y); y += lh * 1.5;
  text("Controls:", x, y); y += lh;
  text("• Arrow keys for movements", x, y); y += lh;
  text("• Click on the cake buttons on the top-right to deliver a cake or press 1/2/3", x, y); y += lh * 1.5;
  text("Tip: Fly over the matching cake sign above the house, then drop!", x, y); y += lh * 1.5;
  text("Shortcut: R = Restart", x, y); y += lh * 2;

  // press any key to start (pulses)
  float alpha = 180 + 75 * sin(millis() / 500.0);
  fill(20, alpha);
  textSize(16);
  text("▶ Press any key to start", x, y);
}

// win/lose overlays show final score + restart option
void drawWinOverlay() {
  drawDimOverlay(180);
  fill(255);
  textAlign(CENTER, CENTER);
  textSize(28);
  text("You delivered everything, you are officially the sweetest witch in town!", width/2, height/2 - 20);
  textSize(18);
  text("Final Score: " + score + ". Press 'R' to take off again!", width/2, height/2 + 20);
}

void drawLoseOverlay() {
  drawDimOverlay(180);
  fill(255);
  textAlign(CENTER, CENTER);
  textSize(28);
  text("Time is up! You lose.", width/2, height/2 - 20);
  textSize(18);
  text("Final Score: " + score + ". Press 'R' to take off again!", width/2, height/2 + 20);
}

// brief red X mar for a wrong drop
void drawWrongFlash() {
  if (wrongFlashTimer > 0) {
    wrongFlashTimer--;
    pushStyle();
    stroke(255, 60, 60);
    strokeWeight(8);
    line(width/2 - 30, 60 - 30, width/2 + 30, 60 + 30);
    line(width/2 - 30, 60 + 30, width/2 + 30, 60 - 30);
    popStyle();
  }
}

// INPUT
// start, restart, and 1/2/3 hotkeys to drop cakes
void keyPressed() {
  if (state == GameState.MENU) {
    state = GameState.PLAYING;
    // so we don't show the menu again in level 1
    introShown = true; 
  }
  if (key == 'r' || key == 'R') {
    startGame();
    return;
  }
  // quick drop hotkeys (1/2/3)
  if (state == GameState.PLAYING) {
    if (key == '1') {
      dropCake(CakeType.CARROT);
    }
    if (key == '2') {
      dropCake(CakeType.FRUIT);
    }
    if (key == '3') {
      dropCake(CakeType.REDVELVET);
    }
  }
}

// start from menu, click cake buttons to drop
void mousePressed() {
  if (state == GameState.MENU) {
    state = GameState.PLAYING;
  }
  if (state == GameState.PLAYING) {
    if (carrotBtn.contains(mouseX, mouseY)) {
       dropCake(CakeType.CARROT);
    }
    else if (fruitBtn.contains(mouseX, mouseY)) {
      dropCake(CakeType.FRUIT);
    }
    else if (redBtn.contains(mouseX, mouseY)) {
      dropCake(CakeType.REDVELVET);
    }
  }
}

// spawn a falling cake at the witch's current position 
void dropCake(CakeType type) {
  if (!currentLevel.needs(type)) {
    // prevents wasting cakes when none are needed
    return; 
  }
  cakes.add(new Cake(type, witch.pos.x, witch.pos.y));
}

// MORE CLASSES
class Vec2 {
  float x, y;
  Vec2(float x, float y) { 
    this.x = x; 
    this.y = y; 
  }
}

// character: position, velocity, input handling, drift, and drawing
class Witch {
  Vec2 pos;
  Vec2 vel = new Vec2(0, 0);
  // arrow-key speed
  float speed  = 9.0; 
  // automatic drift
  float driftX = 0.4;
  float driftY = 0.2;

  Witch(float x, float y) {
    pos = new Vec2(x, y);
  }

  // idle drift so the screen/character move even without input
  void applyDrift(double dx, double dy) {
    vel.x += driftX * (float)dx;
    if (random(1) < 0.5) {
      // 50% chance to drift upward
      vel.y += -driftY * (float)dy;
    } else {
      // 50% chance to drift downward
      vel.y += driftY * (float)dy;
    }
  }

  // apply immediate velocity on arrow key press
  void handleInput() {
    if (keyPressed) {
      if (keyCode == LEFT) {
        vel.x = -speed;
      }
      if (keyCode == RIGHT) {
        vel.x =  speed;
      }
      if (keyCode == UP) {
        vel.y = -speed;
      }
      if (keyCode == DOWN) {
        vel.y =  speed;
      }
    }
  }

  // add velocity + friction and constraint to sky area
  void update() {
    vel.x *= 0.90;
    vel.y *= 0.90;

    pos.x += vel.x;
    pos.y += vel.y;

    // keep player on-screen and above the ground line
    pos.x = constrain(pos.x, 40, width - 40);
    pos.y = constrain(pos.y, 60, height * 0.65);
  }

  void draw() {
    pushMatrix();
    translate(pos.x, pos.y);
    imageMode(CENTER);
    image(witchImg, 0, 0, witchImg.width * 0.25, witchImg.height * 0.25);
    popMatrix();
  }
}

// falling cake projectile --> constant downward velocity until it hits groundY()
class Cake {
  CakeType type;
  Vec2 pos;
  // constant vertical speed
  float vy = 8.0;  
  boolean landed = false;

  Cake(CakeType type, float x, float y) {
    this.type = type;
    this.pos = new Vec2(x, y);
  }

  void update() {
    if (!landed) {
      pos.y += vy;
    }
  }

  void draw() {
    PImage img = getCakeImage(type);
    imageMode(CENTER);
    image(img, pos.x, pos.y, img.width, img.height);
  }
}

// house that requests a specific cake type and celebrates when served
class House {
  // center position 
  float x, y;     
  PImage sprite;
  CakeType request;
  // small heart animation timer
  int celebrateTimer = 0;  
  // has already received its cake
  boolean satisfied = false;   

  House(float x, float y, PImage sprite, CakeType request) {
    this.x = x;
    this.y = y;
    this.sprite = sprite;
    this.request = request;
  }

  // roof y-value for collision threshold
  float roofY() {
    return y - sprite.height/2 + 10;
  }

  // horizontal hitbox 
  float hitLeft()  { 
    return (x + worldOffset) - sprite.width * 0.45; 
  }
  float hitRight() { 
    return (x + worldOffset) + sprite.width * 0.45; 
  }
  boolean underX(float px) { 
    return px >= hitLeft() && px <= hitRight(); 
  }

  // enable celebration visual (heart) as satisfied
  void celebrate() {
    satisfied = true;
    celebrateTimer = 30; // ~0.5s at 60fps
  }

  void draw() {
    imageMode(CENTER);
    image(sprite, x + worldOffset, y);

    // requested cake icon above the roof
    PImage reqImg = getCakeImage(request);
    float rx = x + worldOffset;
    float ry = y - sprite.height/2 - 22;

    // transparent box behind the cake icon (green-tinted when satisfied)
    pushStyle();
    rectMode(CENTER);
    noStroke();
    
    if (satisfied) {
      fill(60, 200, 90, 110);
    } 
    else {
      fill(255, 60);
    }
    rect(rx, ry, 48, 48, 8);
    popStyle();

    // draw the requested cake icon
    imageMode(CENTER);
    image(reqImg, rx, ry, 38, 38);

    // heart celebration when just served
    if (celebrateTimer > 0) {
      celebrateTimer--;
      image(heartImg, x + worldOffset, y - sprite.height/2 - 56, heartImg.width * 0.7, heartImg.height * 0.7);
    }
  }
}

// encapsulates level state: timer, houses, outstanding orders, and spawn logic
class Level {
  PImage bg;
  ArrayList<House> houses;
  // seconds left for this level
  int timeLeft;           
  // remaining orders
  int needCarrot, needFruit, needRed; 
  // timing helper to tick down once per second
  int lastSecondTick; 
  // schedule next house spawn time
  int nextSpawnAtMs = 0;  
  // last spawn position (world coords) to enforce min gaps
  float lastSpawnWorldX;  

  Level(PImage bg, ArrayList<House> houses, int timeLimitSec, int needCarrot, int needFruit, int needRed) {
    this.bg = bg;
    this.houses = houses;
    this.timeLeft = timeLimitSec;
    this.needCarrot = needCarrot;
    this.needFruit = needFruit;
    this.needRed = needRed;
    lastSecondTick = millis();
    // / basically "none yet"
    lastSpawnWorldX = -1e9; 
    scheduleNextSpawn();
  }

  // randomize the next spawn time between MIN_SPAWN_SEC..MAX_SPAWN_SEC
  void scheduleNextSpawn() {
    int gap = (int)random(MIN_SPAWN_SEC*1000, MAX_SPAWN_SEC*1000);
    nextSpawnAtMs = millis() + gap;
  }

  // spawn houses over time, respecting on-screen cap and horizontal spacing
  void maybeSpawnHouse() {
    if (allOrdersComplete()) {
      return;
    }

    // count houses currently on-screen (in screen coords)
    int onScreen = 0;
    for (int i = 0; i < houses.size(); i++) {
      House h = houses.get(i);
      // convert world -> screen x
      float sx = h.x + worldOffset; 
      if (sx > -h.sprite.width && sx < width + 80) {
        onScreen++;
      }
    }
    if (onScreen >= MAX_ONSCREEN_HOUSES) {
      return;
    }

    // time to spawn or not 
    if (millis() < nextSpawnAtMs) {
      return;
    }

    // enforce a minimum world-space gap between spawns to avoid clusters
    // screen's right edge in world coords
    float worldRightEdge = -worldOffset + width;  
    if (worldRightEdge - lastSpawnWorldX < MIN_SPAWN_GAP_PX) {
      return;
    }

    // weight by remaining needs so we spawn useful requests more often
    CakeType t = pickWeightedNeedType();
    // no more orders --> nothing to spawn
    if (t == null) {
      return;
    }

    // choose a random house sprite variety
    PImage sprite;
    float r = random(1); 
    
    if (r < 0.33) {
      sprite = houseStrawImg;
    } 
    else if (r < 0.66) {
      sprite = houseTreeImg;
    } 
    else {
      sprite = houseWoodImg;
    }

    // spawn slightly off the right screen edge (in world coords) --> will scroll in
    float worldX = (width + sprite.width/2 + 40) - worldOffset;
    float y = height - sprite.height/2;

    houses.add(new House(worldX, y, sprite, t));
    lastSpawnWorldX = worldX;
    scheduleNextSpawn();
  }

  // randomly pick a cake type with probability proportional to remaining need
  CakeType pickWeightedNeedType() {
    int c = needCarrot, f = needFruit, r = needRed;
    int total = c + f + r;
    if (total <= 0) {
      return null;
    }
    int roll = (int)random(1, total + 1);
    if (roll <= c) {
      return CakeType.CARROT;
    }
    if (roll <= c + f) {
      return CakeType.FRUIT;
    }
    return CakeType.REDVELVET;
  }

  // decrement one second 
  void updateTimer() {
    int now = millis();
    if (now - lastSecondTick >= 1000) {
      timeLeft = max(0, timeLeft - 1);
      lastSecondTick = now;
    }
  }

  // do we still need any of this cake type
  boolean needs(CakeType t) {
    if (t == CakeType.CARROT) {
      return needCarrot > 0;
    }
    if (t == CakeType.FRUIT) {
      return needFruit > 0;
    }
    return needRed > 0;
  }

  // reduce outstanding orders when a correct delivery occurs
  void decrementOrder(CakeType t) {
    if (t == CakeType.CARROT && needCarrot > 0) {
      needCarrot--;
    }
    else if (t == CakeType.FRUIT && needFruit > 0) {
      needFruit--;
    }
    else if (t == CakeType.REDVELVET && needRed > 0) {
      needRed--;
    }
  }

  // level complete when all three counts hit zero
  boolean allOrdersComplete() {
    return needCarrot == 0 && needFruit == 0 && needRed == 0;
  }

  // the current ground line used to detect cake landings
  float groundY() {
    float gy = height - 60;
    for (int i = 0; i < houses.size(); i++) {
      House h = houses.get(i);
      gy = min(gy, h.roofY());
    }
    return gy + 6;
  }

  // return the house directly beneath an x position
  House houseDirectlyBelow(float x) {
    for (int i = 0; i < houses.size(); i++) {
      House h = houses.get(i);
      if (h.underX(x)) {
        return h;
      }
    }
    return null;
  }
}

// simple clickable rectangle for cake buttons in the top-right
class Button {
  float x, y, w, h;
  CakeType type;
  Button(float x, float y, float w, float h, CakeType type) {
    this.x = x; 
    this.y = y; 
    this.w = w; 
    this.h = h; 
    this.type = type;
  }
  
  void draw(PImage icon) {
    noStroke();
    fill(255, 60);
    rect(x-2, y-2, w+4, h+4, 8);
    imageMode(CORNER);
    image(icon, x, y, w, h);
  }
  
  boolean contains(float px, float py) {
    return px >= x && px <= x+w && py >= y && py <= y+h;
  }
}
