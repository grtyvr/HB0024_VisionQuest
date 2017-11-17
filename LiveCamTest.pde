import gab.opencv.*;
import processing.video.*;
import processing.serial.*;
import ddf.minim.*;
import java.awt.*;

Capture video;
OpenCV opencv;
Serial port;
Minim minim1; 
Minim minim2;
AudioPlayer player;
AudioPlayer targetAquired;

//SoundFile comeCloser, targetAquired;

boolean DEBUGGING = false;

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
int midScreenWindow = 10;  //This is the acceptable 'error' for the center of the screen.

//The degree of change that will be applied to the servo each time we update the position.
int stepSize=1;

boolean newTarget = true;
boolean outOfRange = true;
String[] deploy = {"iSeeYou.wav", "targetAquired.wav", "thereYouAre.wav"};
String[] searching = {"isAnyoneThere.wav", "comeCloser.wav", "wouldYouComeOverHere.wav"};
  
void setup() {

  size(320,240);
  //  size(640, 480);
  midScreenY = (height/2);
  midScreenX = (width/2);
  video = new Capture(this, 640/2, 480/2);
  opencv = new OpenCV(this, 640/2, 480/2);
  opencv.loadCascade(OpenCV.CASCADE_FRONTALFACE);  

  println(Serial.list()); // List COM-ports (Use this to figure out which port the Arduino is connected to)
  
  //select first com-port from the list (change the number in the [] if your sketch fails to connect to the Arduino)
  port = new Serial(this, Serial.list()[32], 115200);   //Baud rate is set to 57600 to match the Arduino baud rate.
  
  //Send the initial pan/tilt angles to the Arduino to set the device up to look straight forward.
  port.write(tiltChannel);    //Send the Tilt Servo ID
  port.write(servoTiltPosition);  //Send the Tilt Position (currently 90 degrees)
  port.write(panChannel);         //Send the Pan Servo ID
  port.write(servoPanPosition);   //Send the Pan Position (currently 90 degrees)

  video.start();
  minim1 = new Minim(this);
//  minim2 = new Minim(this);
//  comeCloser = minim1.loadFile("comeCloser.wav");
//  targetAquired = minim2.loadFile("targetAquired.wav");
}

void draw() {
  scale(1);
  opencv.loadImage(video);

  image(video, 0, 0 );

  noFill();
  stroke(0, 255, 0);
  strokeWeight(3);
  Rectangle[] faces = opencv.detect();
//  println(faces.length);
//  println(midScreenY);
//  println(midScreenX);
  for (int i = 0; i < faces.length; i++) {

    rect(faces[i].x, faces[i].y, faces[i].width, faces[i].height);
  }
  //Find out if any faces were detected.
  if(faces.length > 0){
    //If a face was found, find the midpoint of the first face in the frame.
    //NOTE: The .x and .y of the face rectangle corresponds to the upper left corner of the rectangle,
    //      so we manipulate these values to find the midpoint of the rectangle.
    outOfRange = true;
    if ( newTarget ) {
      int index = int(random(deploy.length));
      player = minim1.loadFile(deploy[index]);
      player.rewind();
      player.play();
      newTarget = false;
    }
    midFaceY = faces[0].y + (faces[0].height/2);
    midFaceX = faces[0].x + (faces[0].width/2);
    if ( DEBUGGING ) {
      println(midScreenY + "," + midScreenX);
      println(midFaceY + "," + midFaceX);    
    }
    //Find out if the Y component of the face is below the middle of the screen.
    if(midFaceY > (midScreenY + midScreenWindow)){
      if (DEBUGGING ) {
        println("Face Too Low, tilt down");
      }
      if(servoTiltPosition >= 5) {     // do not adjust pan position smaller than 5
        servoTiltPosition += stepSize; //If it is below the middle of the screen, update the tilt position variable to lower the tilt servo.
      }
      //Find out if the Y component of the face is above the middle of the screen.
    } else if(midFaceY < (midScreenY - midScreenWindow)){
      if ( DEBUGGING ) {
        println("Face Too High, tilt up:");
      }
      if(servoTiltPosition <= 175) {
        servoTiltPosition -=stepSize; //Update the tilt position variable to raise the tilt servo.
      }
    }
    //Find out if the X component of the face is to the left of the middle of the screen.
    if(midFaceX < (midScreenX - midScreenWindow)){
      if ( DEBUGGING ){
        println("Face on Left:");
      }
      if(servoPanPosition >= 5) {
        servoPanPosition += stepSize; //Update the pan position variable to move the servo to the left.
      }
    //Find out if the X component of the face is to the right of the middle of the screen.
    } else if(midFaceX > (midScreenX + midScreenWindow)){
      if ( DEBUGGING ){
        println("Face on right:");
      }
      if(servoPanPosition <= 175) {
        servoPanPosition -=stepSize; //Update the pan position variable to move the servo to the right.
      }
    }
  } else {
    newTarget = true;
    if (outOfRange) {
      int index = int(random(searching.length));
      player = minim1.loadFile(searching[index]);
      player.rewind();
      player.play();
      outOfRange = false;
    }
}
  //Update the servo positions by sending the serial command to the Arduino.
  port.write(tiltChannel);      //Send the tilt servo ID
  port.write(servoTiltPosition); //Send the updated tilt position.
  port.write(panChannel);        //Send the Pan servo ID
  port.write(servoPanPosition);  //Send the updated pan position.
  delay(1);
}

void captureEvent(Capture c) {
  c.read();
}