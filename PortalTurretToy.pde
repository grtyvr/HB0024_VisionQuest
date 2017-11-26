/*
 *  Portal Turret Toy... v0.2
 *  grtyvr 2017
 *  
 *  now using the Sound library.
 *  added search mode
 *  added timers to the sound playback so that sounds don't play over each other
 *  added timer to play sounds at random intervals while searching
 *
 */
import gab.opencv.*;
import processing.video.*;
import processing.serial.*;
import processing.sound.*;
import java.awt.*;

Capture video;
OpenCV opencv;
Serial port;

//Variables for keeping track of the current servo positions.
char servoTiltPosition = 90;
char servoPanPosition = 90;

//The pan/tilt servo ids for the Arduino serial command interface.
char tiltChannel = 0;
char panChannel = 1;

//These variables hold the x and y location for the middle of the detected face.
int midFaceY=0;
int midFaceX=0;

//The variables correspond to the middle of the screen, and will be compared to the midFace values
int midScreenY = (height/2);
int midScreenX = (width/2);
//This is the acceptable 'error' for the center of the screen.
int midScreenWindow = 40;

//The degree of change that will be applied to the servo each time we update the position.
int stepSize=1;
// The boundaries for the servo positions.  Adjust to suit your needs.
int panMin = 50;
int panMax = 130;
int tiltMin = 70;
int tiltMax = 100;

// Flags to test if we are on the same target as last loop or if we have a new target
// or to test if we have just lost our target
boolean playedDeploySound = false;
boolean outOfRange = true;
boolean playedSearchingSound = false;

// arrays to store the filenames of our deploy and our searching sounds
String[] deployFiles = {"firing.wav", "gotcha.wav",  "hello.wav", "hi.wav", "iSeeYou.wav", "targetAquired.wav","dispensingProduct.wav", "thereYouAre.wav"};
String[] searchingFiles = {"canvasing.wav", "comeCloser.wav", "helloooo.wav",  "isAnyoneThere.wav", "searching.wav", "sentryModeActivated.wav", "wouldYouComeOverHere.wav"};

// declare arrays to store the SoundFile players for searching and deploy SoundFiles
SoundFile[] deploy = new SoundFile[deployFiles.length];
SoundFile[] searching = new SoundFile[searchingFiles.length];

// declare varriable to store our current sound.
SoundFile currentSound;

// constants for generating random time intervals
int minTimeInt = 10;
int maxTimeInt = 40;
// store the interval of time we will use between chirps
int faceLostTimeInterval = int(random(minTimeInt, maxTimeInt));
int chirpTimerStart = 0;

// varriable to keep track of if we are currently playing a sound
// When we started playing it and how long it is  in millis()
int playStartTime = 0;
int currentSoundDuration = 0;

// surrent pan and tilt directions
boolean panRight = true;
boolean tiltUp = true;
int tiltIncrement = 5;

/*********************************
 *  Setup
 */
void setup() {
  // initialize the soundfiles arrays with our sounds
  for (int i = 0; i < deployFiles.length; i++) {
    deploy[i] = new SoundFile(this, deployFiles[i]);  
  }
  for (int i = 0; i < searchingFiles.length; i++) {
    searching[i] = new SoundFile(this, searchingFiles[i]); 
  }
  // set the size of the display window
  size(320,240);
  //  size(640, 480);
  midScreenY = (height/2);
  midScreenX = (width/2);
  video = new Capture(this, 640/2, 480/2);
  opencv = new OpenCV(this, 640/2, 480/2);  
  opencv.loadCascade(OpenCV.CASCADE_FRONTALFACE);  
  // List COM-ports (Use this to figure out which port the Arduino is connected to)
  println(Serial.list()); 
  
  //select first com-port from the list (change the number in the [] if your sketch fails to connect to the Arduino)
  port = new Serial(this, Serial.list()[32], 115200);   //Baud rate is set to 57600 to match the Arduino baud rate.
  
  //Send the initial pan/tilt angles to the Arduino to set the device up to look straight forward.
  writeServoPositions(servoPanPosition, servoTiltPosition);
  
  // start capturing video
  // TO DO:  Add code to detect what port the camera is on.
  video.start();
}

void draw() {
  scale(1);
  opencv.loadImage(video);

  image(video, 0, 0);

  noFill();
  stroke(0, 255, 0);
  strokeWeight(3);
 
/*
 * .detect retruns an array of rectangles for all objects found by the Cascade Classifier currently active
 * in our case it is CASCADE_FRONTALFACE from the line   opencv.loadCascade(OpenCV.CASCADE_FRONTALFACE);  above
 * there is an alternate invocation of detect
 * detect(double scaleFactor , int minNeighbors , int flags, int minSize , int maxSize)
 * there are four flags that can be set:
 *
 * HAAR_SCALE_IMAGE = 1
 *   for each scale factor used the function will downscale the image rather than "zoom" the feature coordinates in the classifier cascade. 
 *   Currently, the option can only be used alone, i.e. the flag can not be set together with the others.
 * HAAR_DO_CANNY_PRUNING = 2
 *   If it is set, the function uses Canny edge detector to reject some image regions that contain too few or too much edges and thus 
 *   can not contain the searched object. The particular threshold values are tuned for face detection and in this case the pruning
 *   speeds up the processing.
 * HAAR_FIND_BIGGEST_OBJECT = 4
 *   If it is set, the function finds the largest object (if any) in the image. That is, the output sequence will contain one (or zero) 
 *   element(s).
 * HAAR_DO_ROUGH_SEARCH = 8
 *   It should be used only when CV_HAAR_FIND_BIGGEST_OBJECT is set and min_neighbors > 0. If the flag is set, the function does not look for
 *   candidates of a smaller size as soon as it has found the object (with enough neighbor candidates) at the current scale. Typically, 
 *   when min_neighbors is fixed, the mode yields less accurate (a bit larger) object rectangle than the regular single-object mode 
 *   (flags=HAAR_FIND_BIGGEST_OBJECT), but it is much faster, up to an order of magnitude. A greater value of min_neighbors may be specified
 *   to improve the accuracy. 
 */
  Rectangle[] faces = opencv.detect(1.2,2,4,15,300);
//  Rectangle[] faces = opencv.detect();
  // draw rectangles around our detected faces  (not needed but good for debugging)
  for (int i = 0; i < faces.length; i++) {                    
    rect(faces[i].x, faces[i].y, faces[i].width, faces[i].height);
  }
  //  Find out if any faces were detected.
  if(faces.length > 0){                                            //  if the length of the array is greater than 0 a face was found
    outOfRange = false;                                            //  since we have a target set our out of range flag to false
    playedSearchingSound = false;                                  //  since we have a target set our playedSearchingSound to false
    if (millis() > playStartTime + currentSoundDuration) {         //  if we are done playing the last sound
      if (playedDeploySound == false) {                            //  check to see if we have played our deploy sound
        playRandomDeploySound();                                   //  play our random Deploy sound
        playedDeploySound = true;                                  //  set our playedDeploySound flag
      }
    }
    midFaceY = faces[0].y + (faces[0].height/2);                   //  find out where the midpoint of our detected face is
    midFaceX = faces[0].x + (faces[0].width/2);                    //  NOTE: The .x and .y of the face rectangle corresponds to the upper left corner of the rectangle,
    trackFace(midFaceX, midFaceY);                                 //  move the servos to track the face
  } else {                                                         //  no faces detected
    playedDeploySound = false;                                     //  since we no longer have a target set our playedDeploySound to false
    if (millis() > playStartTime + currentSoundDuration) {         //  if we are not currently playing a sound
      if (playedSearchingSound == false) {                         //  if we have not already played our Searching Sound
        playRandomSearchingSound();                                //  play our random Searching sound
        playedSearchingSound = true;                               //  set our playedSearchingSound flag
      }
    }
    if (outOfRange==false) {                                       //  check our outOfRange flag to see if we have to initialize our out of range stuff                                         
      chirpTimerStart = millis();                                  //  set timer for chirp interval
      panRight = true;                                             //  start panning right
      tiltUp = true;                                               //  start tilting up
      faceLostTimeInterval = int(random(minTimeInt,maxTimeInt));   //  generate our random chirp interval
      outOfRange = true;                                           //  set our flag so we do this just once.
    }
    delay(10);                                                     //  take a breath
    panRight = searchForFace(panRight);                            //  call our searchForFace routine.  
    if (millis() > faceLostTimeInterval*1000 + chirpTimerStart){   //  if we have extended past our time interval, chirp
      playRandomSearchingSound();
      chirpTimerStart = millis();                                  //  restart our chirp timer
      faceLostTimeInterval = int(random(minTimeInt, maxTimeInt));  //  get a new random wait time
    }
  }
  writeServoPositions(servoPanPosition, servoTiltPosition);        //  write out the servo positions to the microcontroller
  delay(10);
}  // end draw()

/*************************************************************
 * 
 *   Functions and Procedures
 *
 */
 
void writeServoPositions(int panPos, int tiltPos){                 //  Update the servo positions by sending the serial command to the Arduino.
  port.write(tiltChannel);                                         //  Send the tilt servo ID
  port.write(tiltPos);                                             //  Send the updated tilt position.
  port.write(panChannel);                                          //  Send the Pan servo ID
  port.write(panPos);                                              //  Send the updated pan position.
} // end writeServoPositions()

void playRandomSearchingSound(){
      currentSound = searching[int(random(searching.length))];     // get a random sound
      playStartTime = millis();
      currentSound.play();                                         // play it
      currentSoundDuration = int(currentSound.duration()*1000);    // convert the duration of the current sound to ms
} // end playRandomSearchingSound()

void playRandomDeploySound(){
      currentSound = deploy[int(random(deploy.length))];           // get a random current sound from deploy[]
      playStartTime = millis();
      currentSound.play();                                         // play it.
      currentSoundDuration = int(currentSound.duration()*1000);    // convert the duration of the current sound to ms
} // end playRandomDeploySound()

boolean searchForFace(boolean panRight){
/**************************************************
 *
 * Do the stuff we need to do in search mode each loop.
 * increment our position 
 * check if we hit bounds if we have return the new direction true = panRight, false = panLeft
 * at each end of the pan bounds we should move either up or down depending on if we are at 
 * 
 */
  if (panRight) {
    servoPanPosition -= stepSize;                                  //  pan right to decrement position
  } else {                                                         //  otherwise increment step size
    servoPanPosition += stepSize;                                  //  pan left to increment position
  }
  if (servoPanPosition >= panMax) {                                //  end stop at panMax
    panRight = true;                                               //  pan right = decrement position
    tiltUp = tiltServo(tiltUp);                                    //  since we are at the end of a pan row adjust our tilt
  } 
  if (servoPanPosition <= panMin) {                                //  end stop at panMin
    panRight = false;                                              //  pan left to increment position
    tiltUp = tiltServo(tiltUp);                                    //  since we are at the end of a pan row adjust our tilt
  }
  return panRight;
} // end searchForFace

void trackFace(int midFaceX, int midFaceY){
/**************************************************
 *
 * track a face
 *   - if we are high tilt down 
 *   - if we are low tilt up
 *   - if we are left pan right
 *   - if we are right pan left
 */
  if(midFaceY > (midScreenY + midScreenWindow)){                   //  Find out if the Y component of the face is below the middle of the screen.
    if(servoTiltPosition <= tiltMax) {                             //  do not adjust tilt position larger than tiltMax
      servoTiltPosition += stepSize;                               //  If it is below the middle of the screen, update the tilt position variable to lower the tilt servo.
    }
  } else if(midFaceY < (midScreenY - midScreenWindow)){            //  Find out if the Y component of the face is above the middle of the screen.
    if(servoTiltPosition >= tiltMin) {                             //  do not adjust tilt position smaller than tiltMin
      servoTiltPosition -= stepSize;                               //  Update the tilt position variable to raise the tilt servo.
    }
  }
  if(midFaceX < (midScreenX - midScreenWindow)){                   //  Find out if the X component of the face is to the left of the middle of the screen.
    if(servoPanPosition <= panMax) {                               //  do not adjust the servo larger than panMax
      servoPanPosition += stepSize;                                //  Update the pan position variable to move the servo to the left.
    }
  } else if(midFaceX > (midScreenX + midScreenWindow)){            //  Find out if the X component of the face is to the right of the middle of the screen.
    if(servoPanPosition >= panMin) {                               //  do not update the servo lower than panMin
      servoPanPosition -=stepSize;                                 //  Update the pan position variable to move the servo to the right.
    }
  }
}

boolean tiltServo(boolean tiltUp){
/**************************************************
 *
 * tiltServo
 * check if we hit bounds and if we have return the new direction true = tiltUp, false = tiltDown
 * 
 */
  if (tiltUp) {
    servoTiltPosition -= tiltIncrement;
  } else {
    servoTiltPosition += tiltIncrement;
  }
  if (int(servoTiltPosition) <= tiltMin) {
    tiltUp = false;
  }
  if (int(servoTiltPosition) >= tiltMax){
    tiltUp = true;
  }
  return tiltUp;
}

void captureEvent(Capture c) {
  c.read();
}