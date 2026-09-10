//MACRO to Stabilize Images or specific target ROIs in a timelapse video (MACRO CANNOT DO CHANNEL ALIGNMENT)
//TARGETs in ONLY 1 CHANNEL, in 1 Z-plane can be used to stabilize in time, rest of the channels and Z-planes will be shifted similarly
//click on IMAGE STACK you want to align, to get its title, then run macro
//Add the ROIs (ONLY RECTANGULAR ROIs) to the ROI Manager which are to be stabilized or add nothing to stabilize the whole image frame
//Click on the same structure in every frame when asked, and follow rest of the instructions

nTIMEdelay = 100; //wait for nTIMEdelay milliseconds before moving to the next slice

//code list for detecting mouse/keyboard activity (for Windows Operating System)
inputCODEmouseLeftClick = 16;
inputCODEmouseRightClick = 4;
inputCODEshift = 1;
inputCODEctrl = 2; 
inputCODEalt = 8;

run("Set Measurements...", "area mean standard min centroid center fit shape feret's integrated redirect=None decimal=9");

//get image details
id = getTitle();

selectImage(id);
getDimensions(imgWIDTH, imgHEIGHT, imgCHANNELS, imgSLICES, imgFRAMES);
if ((imgFRAMES==1)&&(imgSLICES>1)) { exit("Change SLICES to FRAMES in Image properties and run code again"); }
Stack.getUnits(UnitOfDistanceX, UnitOfDistanceY, UnitOfDistanceZ, UnitOfTime, UnitOfPixelValue);
tINTERVAL = Stack.getFrameInterval();
imgBITdepth = bitDepth();
getVoxelSize(vxlWIDTH, vxlHEIGHT, vxlDEPTH, DistanceUnit);
imgPath = getDirectory("image");
if (imgPath=="") { imgPath = getDirectory("Browse to the location for saving files..."); }
savePath = imgPath +"//"+ "Stabilized_"+id +"//";
File.makeDirectory(savePath);

chOBJ = 1;
if (imgCHANNELS>1)
{
	Dialog.create("Image has more than 1 channel...");
	Dialog.setLocation(0, 0);
	Dialog.addNumber("Which channel number will be used for tracking?", chOBJ);
	Dialog.show();
	chOBJ=Dialog.getNumber();
}
zOBJ = 1;
if (imgSLICES>1)
{
	Dialog.create("Image has more than 1 Z-slice...");
	Dialog.setLocation(0, 0);
	Dialog.addNumber("Which Z-slice number will be used for tracking?", zOBJ);
	Dialog.show();
	zOBJ=Dialog.getNumber();
}

imgStabilizationCoordinatesFile = id+"_StabilizationCoordinates.txt";
if(isOpen("Coordinates")) { close("Coordinates"); }
if(isOpen(imgStabilizationCoordinatesFile)) { close(imgStabilizationCoordinatesFile); }

//Duplicate one series of frames for tracking
if(isOpen("TR4CK")) { close("TR4CK"); }
selectImage(id); run("Select None");
Stack.setChannel(chOBJ);
Stack.setSlice(zOBJ);
getMinAndMax(minGrayValue, maxGrayValue);
selectImage(id); run("Select None"); run("Duplicate...", "title=TR4CK duplicate channels="+chOBJ+" slices="+zOBJ);
selectImage("TR4CK");
run("Grays");
setMinAndMax(minGrayValue, maxGrayValue);
nFRAMESimg = nSlices;

//define arrays to store coordinates for image stabilization
Xall = newArray(nFRAMESimg);
Yall = newArray(nFRAMESimg);
Zall = newArray(nFRAMESimg);
Tall = newArray(nFRAMESimg);

//ask user to get the ROIs which will be stabilized
if (roiManager("count")>0) { roiManager("deselect"); roiManager("delete"); }
selectImage("TR4CK"); setSlice(1); run("Select None");
setTool("rectangle");

selectImage("TR4CK");
Dialog.createNonBlocking("Draw ROIs");
Dialog.setLocation(0,0);
Dialog.addMessage("Click on the image called - TR4CK \n  \nInspect the whole stack to understand how much the target locations shift \nDraw rectangle ROIs on the locations you want to stabilize, add them to ROI Manager \n(Add to ROI Manager shortcut- press Ctrl+'t' or just 't') \n \nDraw large ROIs that include the complete shift \n \nADD ONLY RECTANGULAR ROIs \n \nTo stabilize the whole image, add nothing \n \nClick on OK when done");
Dialog.show();

selectImage("TR4CK");
nROIs = roiManager("count");
if (nROIs>0)
{
	cropXtopLeft = newArray(nROIs);
	cropYtopLeft = newArray(nROIs);
	cropWIDTH = newArray(nROIs);
	cropHEIGHT = newArray(nROIs);
	for (iROI = 0; iROI < nROIs; iROI++)
	{
		roiManager("select", iROI);
		roiManager("Remove Channel Info");
		roiManager("Remove Slice Info");
		roiManager("Remove Frame Info");
		getSelectionBounds(xROI, yROI, roiWIDTH, roiHEIGHT);
		cropXtopLeft[iROI] = xROI;
		cropYtopLeft[iROI] = yROI;
		cropWIDTH[iROI] = roiWIDTH;
		cropHEIGHT[iROI] = roiHEIGHT;
	}
}
else
{
	cropXtopLeft = newArray(1);
	cropYtopLeft = newArray(1);
	cropWIDTH = newArray(1);
	cropHEIGHT = newArray(1);
	getSelectionBounds(xROI, yROI, roiWIDTH, roiHEIGHT); //will take (0,0) coordinates and image width and height
	cropXtopLeft[0] = xROI;
	cropYtopLeft[0] = yROI;
	cropWIDTH[0] = roiWIDTH;
	cropHEIGHT[0] = roiHEIGHT;
}

nStabilize = lengthOf(cropXtopLeft);
nDigitsSTABILIZE = NumberOfDigits(nStabilize); //to find the number of digits in nStabilize

//get coordinates from user input for each ROI
if(isOpen("Coordinates")) { close("Coordinates"); }
Table.create("Coordinates");
Table.setLocationAndSize(0, 0, 150, 200);
if (roiManager("count")>0) { roiManager("deselect"); roiManager("delete"); }
selectImage("TR4CK"); setSlice(1); run("Select None");
for (iROI = 0; iROI < nStabilize; iROI++)
{
	setTool("zoom");
	selectImage("TR4CK"); setSlice(1); run("Select None");
	waitMSGtitle = "Get coordinates for Stabilization-"+(iROI+1);
	if (nROIs == 0) { waitMSGtitle = "Get coordinates for Stabilization"; }
	waitMSGbody = "Track INDIVIDUAL TARGETS with MOUSE CLICKS on the image- TR4CK \n \nAFTER clicking on OK here, click on a point you can track in every slice \nThe slices will be cycled automatically, you have to just click on the point \n \n(Continuously pressing mouse left key will select multiple slices)";
	
	//waitForUser(waitMSGtitle, waitMSGbody);
	Dialog.createNonBlocking(waitMSGtitle);
	Dialog.setLocation(0,0);
	Dialog.addMessage(waitMSGbody);
	Dialog.addNumber("Set time delay between each click (in milliseconds)", nTIMEdelay);
	Dialog.addMessage("Shorter delay --> slices cycle faster --> good for small shifts \n(helps if you want to select the location by pressing continuously)");
	Dialog.addMessage("If the point goes outside the ROI, cancel run, choose bigger ROI", 14, "red");
	Dialog.show();
	nTIMEdelay = Dialog.getNumber();
	
	selectImage(id); setSlice(1);
	setTool("rectangle");
	makeRectangle(cropXtopLeft[iROI], cropYtopLeft[iROI], cropWIDTH[iROI], cropHEIGHT[iROI]);
	iFrame = 1;
	selectImage("TR4CK"); setSlice(iFrame);
	while (iFrame<=nFRAMESimg)
	{
		selectImage("TR4CK"); setSlice(iFrame); run("Select None");
		getCursorLoc(x, y, z, inputAction);
		if (inputAction&inputCODEmouseLeftClick!=0)
		{
			Xall[iFrame-1] = x;
			Yall[iFrame-1] = y;
			Zall[iFrame-1] = z;
			Tall[iFrame-1] = z*tINTERVAL; //stores the physical frame time in seconds or the appropriate units set in the main image
			makePoint(Xall[iFrame-1], Yall[iFrame-1], "tiny magenta cross add");
			Overlay.setPosition(0);
			if (iFrame>1)
			{
				if (Xall[iFrame-2]>(-1))
				{
					makeLine(Xall[iFrame-2], Yall[iFrame-2], Xall[iFrame-1], Yall[iFrame-1]);
					run("Add Selection...");
					Overlay.setPosition(0);
				}
			}
			wait(nTIMEdelay); //wait for nTIMEdelay miliseconds before moving to the next slice
			iFrame = iFrame + 1;
		}
	}
	
	selectWindow("Coordinates");
	if (iROI == 0)
	{
		Table.setColumn("F", Zall);
		Table.setColumn("T("+UnitOfTime+")", Tall);
	}
	Table.setColumn("X"+(iROI+1), Xall);
	Table.setColumn("Y"+(iROI+1), Yall);
}

selectWindow("Coordinates");
saveAs("Results", savePath + imgStabilizationCoordinatesFile);
close("TR4CK");

//Save cropping ROIs separately
if (nROIs>0)
{
	for (iROI = 0; iROI < nROIs; iROI++)
	{
		selectImage(id); setSlice(1); run("Select None");
		makeRectangle(cropXtopLeft[iROI], cropYtopLeft[iROI], cropWIDTH[iROI], cropHEIGHT[iROI]);
		roiManager("Add");
		//GENERATE ROI ID STRING FOR SAVING FILES (because after saving, files are sorted as 1,10,11,...2,20,21,... So, we name files as 01,02,03...10,11,12...etc)
		nDigits = NumberOfDigits(iROI);
		nZeros = nDigitsSTABILIZE - nDigits; //number of zeros to be added before ROI ID
		roiIDstr = "";
		for (i = 1; i <= nZeros; i++) { roiIDstr = roiIDstr + "0"; }
		roiIDstr = roiIDstr + (iROI+1);
		roiManager("select", iROI); roiManager("Rename", "pos"+roiIDstr);
	}
	roiManager("deselect"); roiManager("Save", savePath + "Positions_"+id+"_Cropped.zip"); //save the ROIs for the current file
	if (roiManager("count")>0) { roiManager("deselect"); roiManager("delete"); }
}


//Stabilize image ROIs with user derived coodinates
for (iROI = 0; iROI < nStabilize; iROI++)
{
	//GENERATE ROI ID STRING FOR SAVING FILES (because after saving, files are sorted as 1,10,11,...2,20,21,... So, we name files as 01,02,03...10,11,12...etc)
	nDigits = NumberOfDigits(iROI);
	nZeros = nDigitsSTABILIZE - nDigits; //number of zeros to be added before ROI ID
	roiIDstr = "";
	for (i = 1; i <= nZeros; i++) { roiIDstr = roiIDstr + "0"; }
	roiIDstr = roiIDstr + (iROI+1);
	imgNameStabilized = id+"_Stabilized_pos"+roiIDstr;
	if (nROIs == 0) { imgNameStabilized = id+"_Stabilized"; }
	
	//get stabilization coordinates
	selectWindow(imgStabilizationCoordinatesFile);
	Xall = Table.getColumn("X"+(iROI+1));
	Yall = Table.getColumn("Y"+(iROI+1));
	
	//calculate shifts in (x,y) and find max shift between positions
	Xshift = newArray(nFRAMESimg); Xshift[0] = 0;
	Yshift = newArray(nFRAMESimg); Yshift[0] = 0;
	maxShiftX = 0;
	maxShiftY = 0;
	for (iFrame = 1; iFrame <= (nFRAMESimg-1); iFrame++) //range for storing in Xshift, Yshift arrays: 0 to (nFRAMESimg-1). Arrays at index 0 = 0
	{
		Xshift[iFrame] = round(Xall[iFrame]-Xall[0]);
		Yshift[iFrame] = round(Yall[iFrame]-Yall[0]);
		//store values if this is the maximum shift (in pixels)
		if (abs(Xshift[iFrame])>maxShiftX) { maxShiftX=abs(Xshift[iFrame]); }
		if (abs(Yshift[iFrame])>maxShiftY) { maxShiftY=abs(Yshift[iFrame]); }
	}
	
	//make new image stacks that is bigger by max shift amount to copy and paste individual slices according to how much they are shifted
	for (iC = 1; iC <= imgCHANNELS; iC++)
	{
		for (iZ = 1; iZ <= imgSLICES; iZ++)
		{
			newImage("SH1FT3D"+"_c"+iC+"_z"+iZ, imgBITdepth+"-bit black", (cropWIDTH[iROI]+2*maxShiftX), (cropHEIGHT[iROI]+2*maxShiftY), nFRAMESimg);
			selectImage("SH1FT3D"+"_c"+iC+"_z"+iZ); setVoxelSize(vxlWIDTH, vxlHEIGHT, vxlDEPTH, DistanceUnit); setLocation(0, 0); run("Out [-]"); run("Out [-]"); run("Out [-]");
			run("Re-order Hyperstack ...", "channels=[Channels (c)] slices=[Frames (t)] frames=[Slices (z)]");
			ImgJversion = getVersion();
			if (ImgJversion>"1.52r")
			{
				selectImage("SH1FT3D"+"_c"+iC+"_z"+iZ); Stack.setUnits(UnitOfDistanceX, UnitOfDistanceY, UnitOfDistanceZ, UnitOfTime, UnitOfPixelValue);
			}
			Stack.setFrameInterval(tINTERVAL);
		}
	}
	
	
	//to shift the slice number iFrame and align with the first slice
	if (imgSLICES>1)
	{
		ConcatSTR = "";
	}
	for (iZ = 1; iZ <= imgSLICES; iZ++)
	{
		if (imgCHANNELS>1)
		{
			MergeSTR = ""; //For Merging channels later
			if (isOpen("Merged")==true) { close("Merged"); }
			if (isOpen("Composite")==true) { close("Composite"); }
		}
		for (iC = 1; iC <= imgCHANNELS; iC++)
		{
			if (imgCHANNELS>1)
			{
				selectImage(id); run("Select None");
				Property.set("CompositeProjection", "null");
				Stack.setDisplayMode("grayscale");
				Property.set("CompositeProjection", "Sum");
				Stack.setDisplayMode("composite");
				selectImage(id); run("Select None"); Stack.setChannel(iC); getLut(LUTreds, LUTgreens, LUTblues);
			}
			selectImage(id); run("Select None"); run("Duplicate...", "title=OR1G1N4L_c"+iC+"_z"+iZ+" duplicate channels="+iC+" slices="+iZ);
			selectImage("OR1G1N4L"+"_c"+iC+"_z"+iZ);  setLocation(0, 0); run("Out [-]"); run("Out [-]"); run("Out [-]");
			for (iFrame = 1; iFrame <= nFRAMESimg; iFrame++)
			{
				selectImage("OR1G1N4L"+"_c"+iC+"_z"+iZ); setSlice(iFrame); makeRectangle(Xall[iFrame-1], Yall[iFrame-1], 1, 1); roiManager("Add");
				selectImage("OR1G1N4L"+"_c"+iC+"_z"+iZ); setSlice(iFrame); makeRectangle(cropXtopLeft[iROI], cropYtopLeft[iROI], cropWIDTH[iROI], cropHEIGHT[iROI]); run("Copy");
				selectImage("SH1FT3D"+"_c"+iC+"_z"+iZ); setSlice(iFrame); makeRectangle(maxShiftX-Xshift[(iFrame-1)], maxShiftY-Yshift[(iFrame-1)], cropWIDTH[iROI], cropHEIGHT[iROI]); run("Paste");
			}
			if ((iC==1)&&(iZ==1))
			{
				roiManager("deselect"); roiManager("Save", savePath + imgNameStabilized+"_coordinates.zip"); //save the ROIs for the current file
			}
			if (roiManager("count")>0) { roiManager("deselect"); roiManager("delete"); }
			imgNEWforC = "C"+iC+"_"+imgNameStabilized+"_z"+iZ;
			selectImage("SH1FT3D"+"_c"+iC+"_z"+iZ); run("Select None"); run("Duplicate...", "title=["+imgNEWforC+"] duplicate"); close("SH1FT3D"+"_c"+iC+"_z"+iZ); close("OR1G1N4L"+"_c"+iC+"_z"+iZ);
			selectImage(imgNEWforC); setSlice(1); run("Select None"); run("Enhance Contrast", "saturated=0.35");
			if (imgCHANNELS>1)
			{
				setLut(LUTreds, LUTgreens, LUTblues);
				MergeSTR = MergeSTR + "c"+iC+"=["+imgNEWforC+"] ";
			}
		}
		imgNEWforZ = imgNameStabilized+"_z"+iZ;
		if (imgCHANNELS>1)
		{
			run("Merge Channels...", MergeSTR + "create");
			if (isOpen("Merged")==true) { selectImage("Merged"); }
			if (isOpen("Composite")==true) { selectImage("Composite"); }
			rename(imgNEWforZ);
		}
		if (imgCHANNELS==1)
		{
			selectImage(imgNEWforC);
			rename(imgNEWforZ);
		}
		selectImage(imgNEWforZ);
		if (imgSLICES>1)
		{
			ConcatSTR = ConcatSTR + " image"+iZ+"=["+imgNEWforZ+"]";
		}
	}
	if (imgSLICES>1)
	{
		run("Concatenate...", "  title=["+imgNameStabilized+"] open"+ConcatSTR);
		run("Stack to Hyperstack...", "order=xyczt(default) channels="+imgCHANNELS+" slices="+imgFRAMES+" frames="+imgSLICES+" display=Composite");
		run("Re-order Hyperstack ...", "channels=[Channels (c)] slices=[Frames (t)] frames=[Slices (z)]");
	}
	if (imgSLICES==1)
	{
		selectImage(imgNEWforZ);
		rename(imgNameStabilized);
	}
	saveAs("Tiff", savePath + imgNameStabilized + ".tif");
	close(imgNameStabilized + ".tif");
}

selectImage(id); run("Select None"); setSlice(1);
close(imgStabilizationCoordinatesFile);

//////FUNCTIONS//////

//find number of digits in an integer
function NumberOfDigits(inputINTEGER) //input integers only to count the number of digits
{
	if (inputINTEGER==0) { return 1 }
	if ((isNaN(parseInt(inputINTEGER))==false)&&(inputINTEGER==round(inputINTEGER)))
	{
		nDigits = 0; dummy = inputINTEGER;
		while (dummy>0)
		{
			dummy = (dummy - floor(dummy%10))/10;
			nDigits = nDigits + 1; //number of digits in the numerical value of nCells
		}
		return nDigits
	}
	else { return NaN }
}