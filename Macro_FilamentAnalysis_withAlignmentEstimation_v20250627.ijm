/*
 * Macro for Filament segmentation and analysis of length, width, and relative orientation
 * uses RIDGE DETECTION Plugin to find FILAMENTS
 * 
 * INSTRUCTIONS:
 * THE IMAGE MUST BE SCALED TO A PHYSICAL DISTANCE (eg., image scale bar will show distances in micrometers, not pixels)
 * Open and click on image/stack containing filament markers, run macro
 * When asked to provide cell boundary ROIs, add them
 * You may choose from the pre-made masks, or make new ones. Only the ROIs in the ROI Manager will be counted, so now is your chance to add only the properly focussed cells
 * You may also add any pre-saved ROIs
 * 
 * PREFERABLY, OPTIMIZE THE RIDGE DETECTION PARAMETERS BEFOREHAND
 * 
 * Algorithm:
 * 1. ACCUMULATE IMAGE FILTERS (like Unsharp Mask, Top Hat Filter, etc) WITH INCREASING RADII:- TO SHARPEN FILAMENTS, NORMALIZE INTENSITIES, AND REDUCE BACKGROUND, thereby INCREASING CONTRAST
 * 2. REMOVE EDGE ARTEFACTS AT CELL BOUNDARIES (Erosion operation in Binary masks)
 * 3. APPLY RIDGE DETECTION ON EACH CELL (COPY-PASTED IN DIFFERENT SLICES OF A 32-bit IMAGE), MEASURE FILAMENT PARAMETERS
 */

run("Set Measurements...", "area mean standard min centroid fit shape feret's integrated redirect=None decimal=9");
run("Options...", "iterations=1 count=1 black pad edm=32-bit");

id = getTitle();

selectImage(id);
getDimensions(widthIMG, heightIMG, channelsIMG, slicesIMG, framesIMG);
getPixelSize(DistanceUnit, pixelWidth, pixelHeight); scaleIMG = 1/pixelWidth;

//Close previously generated windows if they are open
if (isOpen("MaskOfCells")==true) { close("MaskOfCells"); }
if (isOpen("a0R1G1N4L")==true) { close("a0R1G1N4L"); }
if (isOpen("OnlyCells")==true) { close("OnlyCells"); }
if (isOpen("OnlyCellMASKs")==true) { close("OnlyCellMASKs"); }
if (isOpen("F1L4MENTS")==true) { close("F1L4MENTS"); }
if (isOpen("Processed32bit_"+id)==true) { close("Processed32bit_"+id); }
if (isOpen("FilamentAlignmentIndex")==true) { close("FilamentAlignmentIndex"); }
if (isOpen("FILAMENT_LENGTH")==true) { close("FILAMENT_LENGTH"); }
if (isOpen("FILAMENT_WIDTH")==true) { close("FILAMENT_WIDTH"); }
if (isOpen("FILAMENT_AREA")==true) { close("FILAMENT_AREA"); }
if (isOpen("FILAMENT_ANGLE")==true) { close("FILAMENT_ANGLE"); }
if (isOpen("FILAMENT_ALIGNMENT")==true) { close("FILAMENT_ALIGNMENT"); }
if (isOpen("Log")==true) { close("Log"); }

//Correct channel selection
chF1L = 1;
if (channelsIMG>1)
{
	Dialog.create("Image has more than 1 channel...");
	Dialog.setLocation(0, 0);
	Dialog.addNumber("Which channel number contains the filaments you want to segment?", chF1L);
	Dialog.show();
	chF1L=Dialog.getNumber();
}

MicroscopeCHOICES = newArray("Confocal (or Sharp images)","Widefield (or somewhat blurry images");
MicroscopeCHOICE = MicroscopeCHOICES[1];
nF1LT3Rs = 20; //Number of times filtered images are accumulated (higher numbers lead to more intensity smoothing around the filamentous structures)
enhanceLOCALcontrast = false; //enhance local contrast in image based on pixel block size by CLAHE
applyRidgeDetection = true; //choice to do only filtering, no filament extraction
keepFilteredImage = false; //choice to keep filtered image for further inspection
drawFilaments = true; //choice to draw filaments with alignment index
lengthEDGEerode = 10; //length (in pixels) of the cell edge to be removed (e.g., to remove lamellipodial actin enrichment appearing as filaments)
mainNEIGHBOURHOODsize = 5; //in MICRONS/physical distance unit preferably. Primary distance of neighbouring filaments from a target filament to determine if they are neighbours to be averaged later
chooseNEIGHBOURHOODsizeRANGE = false;
Dialog.create("PARAMETERS FOR FILAMENT ANALYSIS");
Dialog.setLocation(0, 0);
Dialog.addMessage("FILAMENT CONTRAST ENHANCEMENT AND NOISE REDUCTION PARAMETERS", 12, "blue");
Dialog.addChoice("Choose imaging mode", MicroscopeCHOICES, MicroscopeCHOICE);
Dialog.addMessage("The code enhances filament intensity/contrast by accumulating image filters \nHigher numbers lead to more intensity smoothing around the filaments");
Dialog.addNumber("Number of times filtered images are accumulated", nF1LT3Rs);
Dialog.addCheckbox("Check this box if you want to enhance local contrast by CLAHE (code will run slower)", enhanceLOCALcontrast);
Dialog.addCheckbox("Check this box if you want to apply Ridge Detection plugin", applyRidgeDetection);
Dialog.addMessage("***uncheck if you just want to have just the filtered image \nThe subsequent parameters below can be ignored if you uncheck \nYou can try applying Ridge Detection on the filtered image to optimize parameters \nMAKE SURE TO CONVERT TO unsaturated 8-bit BEFORE APPLYING Ridge Detection");
//Dialog.addMessage(" \n");
Dialog.addCheckbox("Keep the processed images (pre-Ridge Detection) for inspecting later", keepFilteredImage);
Dialog.addCheckbox("Represent detected filaments in a separate image with width and alignment indicators", drawFilaments);
//Dialog.addMessage(" \n");
Dialog.addMessage("The code erodes out the cell edge to remove artefactual filamentous structures");
Dialog.addNumber("Length of cell edge to be eroded away (in PIXELS)", lengthEDGEerode);
//Dialog.addMessage(" \n");
Dialog.addMessage("FILAMENT NEIGHBOURHOOD DEFINITION PARAMETERS", 12, "blue");
Dialog.addMessage("USE "+DistanceUnit+" TO DEFINE NEIGHBOURHOOD SIZE", 14, "red");
Dialog.addNumber("Size of filament neighbourhood to be used for average alignment estimation", mainNEIGHBOURHOODsize);
Dialog.addMessage("***Neighbourhood size = Distance between 2 filaments to consider them as neighbours, \n and calculate their alignment index in the local neighbourhood");
Dialog.addMessage("Neighbourhood size is better expressed in MICRONS/any physical distance unit \nUsing PIXELS makes calculations uncomparable over different imaging conditions)", 12, "red");
Dialog.addCheckbox("Check this box to calculate alignment over a range of neighbourhood sizes", chooseNEIGHBOURHOODsizeRANGE);
Dialog.addMessage("***Computing filament alignment over a large size range makes the code very very slow");
Dialog.show();

MicroscopeCHOICE = Dialog.getChoice();
nF1LT3Rs = Dialog.getNumber();
enhanceLOCALcontrast = Dialog.getCheckbox();
applyRidgeDetection = Dialog.getCheckbox();
keepFilteredImage = Dialog.getCheckbox();
drawFilaments = Dialog.getCheckbox();
lengthEDGEerode = Dialog.getNumber();
mainNEIGHBOURHOODsize = Dialog.getNumber();
chooseNEIGHBOURHOODsizeRANGE = Dialog.getCheckbox();
minSZnbr = 1;
maxSZnbr = 10;
stepSizeNbr = 1;
if ((chooseNEIGHBOURHOODsizeRANGE == true)&&(applyRidgeDetection == true))
{
	Dialog.create("SIZE RANGE TO DEFINE NEIGHBOURHOOD");
	Dialog.setLocation(0, 0);
	Dialog.addMessage("GIVE SIZE RANGE IN  "+DistanceUnit, 16, "red");
	Dialog.addNumber("Minimum size of filament neighbourhood", minSZnbr);
	Dialog.addNumber("Maximum size of filament neighbourhood", maxSZnbr);
	Dialog.addNumber("Step-size of increment", stepSizeNbr);
	Dialog.addMessage("(Step-size of increments will be in "+DistanceUnit+") \n \nDecimal points allowed, but REMEMBER, \n Computing over a large size range \n will make the code runtime very long");
	Dialog.show();
	minSZnbr = Dialog.getNumber();
	maxSZnbr = Dialog.getNumber();
	stepSizeNbr = Dialog.getNumber();
	if (minSZnbr > maxSZnbr) //avoiding avoidable mistakes
	{
		temp = minSZnbr;
		minSZnbr = maxSZnbr;
		maxSZnbr = temp;
	}
}
else
{
	minSZnbr = mainNEIGHBOURHOODsize;
	maxSZnbr = mainNEIGHBOURHOODsize;
}

msg2usrWrongNBRsz = "";
if ((mainNEIGHBOURHOODsize<minSZnbr)||(mainNEIGHBOURHOODsize>maxSZnbr)) //avoiding avoidable mistakes
{
	mainNEIGHBOURHOODsize = minSZnbr + ((maxSZnbr-minSZnbr)/2);
	msg2usrWrongNBRsz = "The neighbourhood size for average alignment estimation was outside the min/max size range";
}


if (applyRidgeDetection == true)
{
	selectImage(id); savePath=getDirectory("image");
	if (savePath=="") { savePath=getDir("Browse to the location for saving files..."); }
	File.makeDirectory(savePath+"//"+id+"_FilamentData");
	savePath=savePath+"//"+id+"_FilamentData"+"//";
}

//RIDGE DETECTION PARAMETERS
makeMASKScells = true;
lineWIDTH = 5;
highCONTRAST = 100;
lowCONTRAST = 20;
minimumLineLENGTHpxls = 10;
maximumLineLENGTHpxls = 0;
extendLINE = false;
correctPOSITION = true;
saveBinaryMasks = true;
OverlapRESOLUTION = newArray("NONE","SLOPE");
resolveOVERLAP = OverlapRESOLUTION[0]; //If overlapping lines are resolved with SLOPE, more curvy lines will be considered
cutoffLENGTH = 4; //in MICRONS/any physical distance, minimum filament length to be considered for averaging values
cutoffWIDTH = 0; //in MICRONS/any physical distance, minimum filament width to be considered for averaging values
if (applyRidgeDetection == true)
{
	Dialog.create("Parameters for RIDGE DETECTION PLUGIN...");
	Dialog.setLocation(0, 0);
	Dialog.addCheckbox("Uncheck this box if you already have cell boundary ROIs and don't need to make new masks", makeMASKScells);
	Dialog.addNumber("Average LINE-WIDTH (in pixels)", lineWIDTH);
	Dialog.addNumber("High-contrast (8-bit range)", highCONTRAST);
	Dialog.addNumber("Low-contrast (8-bit range)", lowCONTRAST);
	//Dialog.addMessage(" \n");
	Dialog.addNumber("Minimum LINE-LENGTH to be segmented (in pixels)", minimumLineLENGTHpxls);
	Dialog.addNumber("Maximum LINE-LENGTH to be segmented (in pixels)", maximumLineLENGTHpxls);
	Dialog.addMessage("***putting 0 in LINE-LENGTH parameters disregards filament length");
	Dialog.addMessage(" \n");
	Dialog.addCheckbox("Extend Line?", extendLINE);
	Dialog.addCheckbox("Correct Position?", correctPOSITION);
	Dialog.addMessage("***these parameters account for uneven intensities around filaments");
	//Dialog.addMessage(" \n");
	Dialog.addCheckbox("Save Binary Mask of ALL detected filaments?", saveBinaryMasks);
	Dialog.addChoice("Resolve OVERLAPS?", OverlapRESOLUTION, resolveOVERLAP);
	Dialog.addMessage("***If overlapping lines are resolved with SLOPE,\nLONGER and MORE CURVY lines passing over junctions will be considered,\nThe code will also need a lot more time to run");
	//Dialog.addMessage(" \n");
	Dialog.addMessage("SPECIFY FILAMENT PROPERTIES FOR COMPUTING AVERAGES...", 14, "blue");
	Dialog.addMessage("THE VALUES BELOW ARE EXPRESSED IN "+DistanceUnit, 16, "red");
	Dialog.addNumber("Minimum FILAMENT-LENGTH to be considered for averaging values", cutoffLENGTH);
	Dialog.addNumber("Minimum FILAMENT-WIDTH to be considered for averaging values", cutoffWIDTH);
	Dialog.addMessage("(put 0 if you don't want to specify anything)");
	Dialog.show();
	makeMASKScells = Dialog.getCheckbox();
	lineWIDTH = Dialog.getNumber();
	highCONTRAST = Dialog.getNumber();
	lowCONTRAST = Dialog.getNumber();
	minimumLineLENGTHpxls = Dialog.getNumber();
	maximumLineLENGTHpxls = Dialog.getNumber();
	extendLINE = Dialog.getCheckbox();
	correctPOSITION = Dialog.getCheckbox();
	saveBinaryMasks = Dialog.getCheckbox();
	resolveOVERLAP = Dialog.getChoice();
	cutoffLENGTH = Dialog.getNumber();
	cutoffWIDTH = Dialog.getNumber();
}
if (extendLINE == true) { extendLINE = " extend_line"; }
if (extendLINE == false) { extendLINE = ""; }
if (correctPOSITION == true) { correctPOSITION = " correct_position"; }
if (correctPOSITION == false) { correctPOSITION = ""; }
if (saveBinaryMasks == true) { saveBinaryMasks = " make_binary"; }
if (saveBinaryMasks == false) { saveBinaryMasks = ""; }

//CALCULATED PARAMETERS FOR RIDGE DETECTION (MANDATORY)
sigmaRD = (lineWIDTH/(2*sqrt(3))) + 0.5;
thresholdTERM = 0.17 * (lineWIDTH/(sqrt(2*PI)*pow(sigmaRD, 3))) / exp((pow(lineWIDTH, 2)/(8*pow(sigmaRD, 2))));
upperTHRESHOLD = highCONTRAST*thresholdTERM;
lowerTHRESHOLD = lowCONTRAST*thresholdTERM;

if (applyRidgeDetection == true)
{	
	////MAKE MASKS FOR USER TO SELECT CELL BOUNDARIES
	timeRunMASK = 0;
	if (makeMASKScells == true)
	{
		chCBm = chF1L;
		if (channelsIMG>1)
		{
			Dialog.create("Cell Boundary masks...");
			Dialog.setLocation(0, 0);
			Dialog.addNumber("Which channel number do you want to use to make cell boundary masks?", chCBm);
			Dialog.addMessage("Tip: Choose a channel which shows the full cell boundary,\n and least intensity variations within the cell");
			Dialog.show();
			chCBm = Dialog.getNumber();
		}
		radF1LT3R = round(lineWIDTH); //size of smoothing filter in pixels
		radOUTLIERsize = round(lineWIDTH/5); //size of white dots in pixels (which are left after thresholding)
		algoTHRESHOLDcells = "Triangle"; //"Yen";
		timeBeginMASK = getTime();
		selectImage(id); run("Select None"); run("Duplicate...", "title=M0 duplicate channels="+chCBm);
		selectImage("M0"); run("Remove Overlay"); run("Grays"); run("Enhance Contrast", "saturated=0.35"); run("Out [-]"); run("Out [-]"); run("Out [-]");
		//Adjust brightness contrast individually on all slices
		selectImage("M0"); nSlicesMASK = nSlices;
		for (iSlice=1; iSlice<=nSlicesMASK; iSlice++)
		{
			selectImage("M0"); setSlice(iSlice);
			run("Enhance Contrast", "saturated=0.2");
			run("Apply LUT", "slice");
		}
		selectImage("M0"); setSlice(1);
		//Smooth image while preserving edges
		selectImage("M0"); run("Median...", "radius="+radF1LT3R+" stack");
		//Threshold
		selectImage("M0"); setAutoThreshold(algoTHRESHOLDcells+" dark no-reset stack");
		selectImage("M0"); run("Convert to Mask", "method"+algoTHRESHOLDcells+" background=Dark black");
		//Run the Binary operation "Close" to connect closely spaced gaps
		selectImage("M0"); run("Close-", "stack");
		//Remove small bright dots
		selectImage("M0"); run("Remove Outliers...", "radius="+radOUTLIERsize+" threshold=254 which=Bright stack");
		//Duplicate the mask for user to work on
		selectImage("M0"); run("Select None"); run("Duplicate...", "title=MaskOfCells duplicate"); close("M0");
		selectImage("MaskOfCells"); run("Out [-]"); run("Out [-]");
		timeEndMASK = getTime();
		timeRunMASK = (timeEndMASK-timeBeginMASK)/1000; //mask making run time in seconds
	}
	
	//PROMPT USER TO CREATE CELL BOUNDARY ROIs
	if (roiManager("count")>0) { roiManager("deselect"); roiManager("delete"); } //clear ROI Manager
	if (timeRunMASK>0)
	{
		waitMSG2User = "Add all ROIs of relevant cell boundaries to the ROI manager... \nClick OK when finished \n \nNB: You can make a different set of masks if you want, just add cell boundaries to ROI Manager \n*** DON'T INCLUDE TAIL-LIKE STRUCTURES TO AVOID ARTEFACTS \n \nCAUTION: NO ROI SHOULD OVERLAP \n \n <<Masks made in "+timeRunMASK+" s>>";
	}
	else
	{
		waitMSG2User = "Add all ROIs of relevant cell boundaries to the ROI manager... \nClick OK when finished \n \nNB: You can make a different set of masks if you want, just add cell boundaries to ROI Manager \n*** DON'T INCLUDE TAIL-LIKE STRUCTURES TO AVOID ARTEFACTS \n \nCAUTION: NO ROI SHOULD OVERLAP";
	}
	waitForUser("WAITING FOR CELL ROIs", waitMSG2User);
	//////////////////////////////////////////////////////////////////////////////////////////////////////////
	//roiManager("Open", "P:/h919/lappalainen/Parijat/TrialMACROS_ImageJ/STRESS_FIBER_ANALYSIS___MacroTRIALS/ActinSF_2slices.tif_RoiSet_Cells.zip");////Debugging line. Can be deleted////
	//////////////////////////////////////////////////////////////////////////////////////////////////////////
	roiManager("deselect"); roiManager("Sort");
	roiManager("deselect"); roiManager("Save", savePath+"//"+substring(id,0,(lengthOf(id)-4))+"_Cells.zip"); //save user-input ROIs
	setTool("zoom");
	close("MaskOfCells");
	nCells = roiManager("count");
	
	selectImage(id); run("Select None"); run("Duplicate...", "title=a0R1G1N4L duplicate channels="+chF1L);
	selectImage("a0R1G1N4L"); run("Out [-]"); run("Out [-]"); run("Out [-]"); run("Out [-]");
	selectImage("a0R1G1N4L"); run("Set Scale...", "distance="+scaleIMG+" known=1 unit="+DistanceUnit);
	run("Clear Results");
	selectImage("a0R1G1N4L"); roiManager("deselect"); roiManager("measure");
	selectWindow("Results");
	AreaCELLS = Table.getColumn("Area");
	run("Clear Results");
	close("Results");
	
	//MAKE A NEW IMAGE OF CELLS MARKED BY USER WHERE EACH SLICE OF THE IMAGE STACK CONTAINS ONE CELL
	newImage("OnlyCells", "32-bit black", widthIMG, heightIMG, nCells); run("Out [-]"); run("Out [-]"); run("Out [-]"); run("Out [-]");
	selectImage("OnlyCells"); run("Set Scale...", "distance="+scaleIMG+" known=1 unit="+DistanceUnit);
	selectImage("OnlyCells"); run("Multiply...", "value=0 stack"); //make all pixels 0 in this 32-bit image
	for (iCell = 0; iCell < nCells; iCell++)
	{
		selectImage("a0R1G1N4L"); roiManager("select", iCell); run("Copy");
		selectImage("OnlyCells"); roiManager("select", iCell); setSlice(iCell+1); run("Paste");
	}
	
	////TRIMMING CELL EDGES TO REMOVE ARTEFACTS (like lamellipodial actin accumulation)
	//DUPLICATE THE OnlyCells IMAGE FOR MAKING BINARY MASKS TO APPLY THE Erode FUNCTION
	selectImage("OnlyCells"); run("Select None"); run("Duplicate...", "title=OnlyCellMASKs duplicate");
	selectImage("OnlyCellMASKs"); run("Out [-]"); run("Out [-]"); run("Out [-]"); run("Out [-]");
	selectImage("OnlyCellMASKs"); run("8-bit");
	selectImage("OnlyCellMASKs"); setMinAndMax(0, 1); run("Apply LUT", "stack");
	selectImage("OnlyCellMASKs"); run("Make Binary", "method=Percentile background=Dark calculate black");
	selectImage("OnlyCellMASKs"); run("Fill Holes", "stack");
	//TRIM CELL EDGES BY APPLYING BINARY EROSION
	for (iErode = 0; iErode < lengthEDGEerode; iErode++)
	{
		selectImage("OnlyCellMASKs"); run("Select None"); run("Erode", "stack");
	}
	selectImage("OnlyCellMASKs"); run("Select None"); run("Divide...", "value=255 stack"); //to make a 0 and 1 image
	//MULTIPLY WITH OnlyCells TO MAKE THE TRIMMED CELL EDGE PIXELS 0
	imageCalculator("Multiply create 32-bit stack", "OnlyCells","OnlyCellMASKs"); close("OnlyCellMASKs"); close("OnlyCells");
	selectImage("Result of OnlyCells"); rename("OnlyCells"); run("Out [-]"); run("Out [-]"); run("Out [-]");
	roiManager("deselect"); roiManager("delete"); //clear all cell boundary ROIs
}
else
{
	selectImage(id); run("Select None"); run("Duplicate...", "title=OnlyCells duplicate channels="+chF1L);
	selectImage("OnlyCells"); run("32-bit"); run("Out [-]"); run("Out [-]"); run("Out [-]"); run("Out [-]");
	selectImage("OnlyCells"); run("Set Scale...", "distance="+scaleIMG+" known=1 unit="+DistanceUnit);
}

////FILAMENT DETECTION

////FILAMENT ENRICHMENT- ACCUMULATE FILTERED IMAGES TO SHARPEN FILAMENTS, NORMALIZE INTENSITIES, AND REDUCE BACKGROUND
//[function arguments:- (imageName, operation, beginRADIUS, endRADIUS, stepSIZE, FilterMethod); input image = only single channel image stack]
AccumulateFilters("OnlyCells", "Max", 1, nF1LT3Rs, 1, "Unsharp Mask"); //output image = ACCUMULAT3D
selectImage("ACCUMULAT3D"); rename("USMmax");
AccumulateFilters("OnlyCells", "Min", 1, nF1LT3Rs, 1, "Unsharp Mask"); //output image = ACCUMULAT3D
selectImage("ACCUMULAT3D"); rename("USMmin");

imageCalculator("Average create 32-bit stack", "USMmax","USMmin"); close("USMmax"); close("USMmin");
selectImage("Result of USMmax"); rename("toTopHat"); run("Out [-]"); run("Out [-]"); run("Out [-]"); run("Out [-]");

if (MicroscopeCHOICE == MicroscopeCHOICES[1])
{
	//Sharpen further
	AccumulateFilters("toTopHat", "Average", 1, nF1LT3Rs, 2, "Top Hat"); //output image = ACCUMULAT3D
	selectImage("ACCUMULAT3D"); close("toTopHat");
}
else { selectImage("toTopHat"); rename("ACCUMULAT3D"); }

//Smoothen image to get rid of pixel noise
selectImage("ACCUMULAT3D"); run("Select None"); run("Smooth", "stack");

//CONVERT IMAGE TO 8-bit SLICE-BY-SLICE (with each slice containing one cell), TO INDEPENDENTLY NORMALIZE EACH CELL'S INTENSITY RANGE WITHIN 0-255 (as the Ridge Detection plugin can only work on 8-bit images)
//OPTIONALLY, ENHANCE LOCAL CONTRAST ON ALL SLICES INDIVIDUALLY AFTER CONVERTING TO 8-bit
selectImage("ACCUMULAT3D"); nslicesIMG = nSlices;
if (enhanceLOCALcontrast == true)
{
	ELCblocksize = maxOf(31,round(widthIMG/100));
	ELChistogram = 256;
	ELCslope = 3;
}
for (iELC = 1; iELC <= nslicesIMG; iELC++)
{
	selectImage("ACCUMULAT3D"); setSlice(iELC); run("Select None"); run("Duplicate...", "title=s_"+iELC);
	selectImage("s_"+iELC); run("Select None"); resetMinAndMax; run("Out [-]"); run("Out [-]"); run("Out [-]");
	//selectImage("s_"+iELC); run("Enhance Contrast...", "saturated=0.9 process_all"); run("Out [-]"); run("Out [-]"); run("Out [-]");
	selectImage("s_"+iELC); setOption("ScaleConversions", true); run("8-bit"); run("Select None");
	if (enhanceLOCALcontrast == true)
	{
		if (applyRidgeDetection == true) { ELCblocksize = round(sqrt(AreaCELLS[iELC-1]/(pixelWidth*pixelHeight))/4); }
		selectImage("s_"+iELC); run("Select None"); run("Enhance Local Contrast (CLAHE)", "blocksize="+ELCblocksize+" histogram="+ELChistogram+" maximum="+ELCslope+" mask=*None*");
	}
	if (iELC>1) { run("Concatenate...", "  title=s_1 open image1=s_1 image2=s_"+iELC+" image3=[-- None --]"); run("Out [-]"); run("Out [-]"); run("Out [-]"); }
}
close("ACCUMULAT3D");
selectImage("s_1"); run("Select None"); setSlice(1); run("Duplicate...", "title=F1L4MENTS duplicate"); close("s_1");

selectImage("F1L4MENTS"); run("Out [-]"); run("Out [-]"); run("Out [-]"); run("Out [-]");

close("OnlyCells");


if (isOpen("a0R1G1N4L")==true) { close("a0R1G1N4L"); }

if (keepFilteredImage == true)
{
	selectImage("F1L4MENTS"); run("Select None"); setSlice(1); run("Duplicate...", "title=[Processed32bit_"+id+"] duplicate");
	selectImage("Processed32bit_"+id); run("Select All"); maxINTENSITYwholeImg = getValue("Max");
	selectImage("Processed32bit_"+id); run("Select None"); setMinAndMax(0, round(0.5*maxINTENSITYwholeImg)); run("Out [-]"); run("Out [-]"); run("Out [-]");
	selectImage("F1L4MENTS");
	if (applyRidgeDetection == false) { close("F1L4MENTS"); }
}

///*

if (applyRidgeDetection == true)
{
	
	//APPLY RIDGE DETECTION ON EACH CELL SEPARATELY, MEASURE FILAMENT PARAMETERS
	if (isOpen("Summary")==true) { close("Summary"); }
	
	Table.create("FILAMENT_LENGTH");
	Table.setLocationAndSize(0, 0, 300, 200, "FILAMENT_LENGTH");
	Table.create("FILAMENT_WIDTH");
	Table.setLocationAndSize(0, 100, 300, 200, "FILAMENT_WIDTH");
	Table.create("FILAMENT_AREA");
	Table.setLocationAndSize(0, 200, 300, 200, "FILAMENT_AREA");
	Table.create("FILAMENT_ANGLE");
	Table.setLocationAndSize(0, 300, 300, 200, "FILAMENT_ANGLE");
	Table.create("FILAMENT_ALIGNMENT");
	Table.setLocationAndSize(0, 400, 300, 200, "FILAMENT_ALIGNMENT");
	
	//FIND NUMBER OF DIGITS IN nCells (will be useful for naming files later)
	nDigitsCELLS = NumberOfDigits(nCells);
	
	if (isOpen("Log")==true) { close("Log"); }
	for (iCell = 1; iCell <= nCells; iCell++)
	{
		//GENERATE CELL ID STRING FOR SAVING FILES (because after saving, files are sorted as 1,10,11,...2,20,21,... So, we name files as 01,02,03...10,11,12...etc)
		nDigits = NumberOfDigits(iCell);
		nZeros = nDigitsCELLS - nDigits; //number of zeros to be added before cell ID
		cellIDstr = "";
		for (i = 1; i <= nZeros; i++) { cellIDstr = cellIDstr + "0"; }
		cellIDstr = cellIDstr + iCell;
		
		////RUN Ridge Detection plugin AFTER DUPLICATING EACH SLICE OF THE PROCESSED IMAGE (beacuse running Ridge Detection on large image stacks might crash the program)
		if (roiManager("count")>0) { roiManager("deselect"); roiManager("delete"); } //clear ROI Manager
		if (isOpen("forR1DG3detection")==true) { close("forR1DG3detection"); }
		selectImage("F1L4MENTS"); setSlice(iCell); run("Select None"); run("Duplicate...", "title=forR1DG3detection");
		selectImage("forR1DG3detection"); run("Out [-]"); run("Out [-]"); run("Out [-]"); run("Out [-]"); run("Set Scale...", "distance="+scaleIMG+" known=1 unit="+DistanceUnit);
		//APPLY RIDGE DETECTION
		run("Ridge Detection", "line_width="+lineWIDTH+" high_contrast="+highCONTRAST+" low_contrast="+lowCONTRAST+correctPOSITION+" estimate_width"+extendLINE+" displayresults add_to_manager"+saveBinaryMasks+" method_for_overlap_resolution="+resolveOVERLAP+" sigma="+sigmaRD+" lower_threshold="+lowerTHRESHOLD+" upper_threshold="+upperTHRESHOLD+" minimum_line_length="+minimumLineLENGTHpxls+" maximum="+maximumLineLENGTHpxls);
		if (isOpen("Junctions")==true) { close("Junctions"); }
		if (isOpen("Results")==true) { close("Results"); }
		ridgeDetectERRORmsg = "";
		if (isOpen("Summary") == false)
		{
			if (isOpen("Exception")==true) { close("Exception"); }
			ridgeDetectERRORmsg = ridgeDetectERRORmsg + "\t" + cellIDstr;
			close("forR1DG3detection");
			continue;
		}
		selectWindow("Summary");
		LineLENGTHall = Table.getColumn("Length");
		LineWIDTHmeanAll = Table.getColumn("Mean line width");
		close("Summary");
		numberSFdetected = lengthOf(LineLENGTHall);
		LineAREAall = newArray(numberSFdetected);
		sumAreaFilaments = 0;
		for (iSF = 0; iSF < numberSFdetected; iSF++)
		{
			LineAREAall[iSF] = LineLENGTHall[iSF]*LineWIDTHmeanAll[iSF];
			sumAreaFilaments = sumAreaFilaments + LineAREAall[iSF];
		}
		
		//remove ROIs that are NOT FREEHAND LINES
		nROIs = roiManager("count");
		i = 0;
		while (i < nROIs)
		{
			roiManager("select", i);
			type = selectionType();
			if (type != 7) //'7' is freehand line
			{
				roiManager("delete");
				nROIs = roiManager("count");
			}
			else { i = i + 1; }
		}
		
		//SAVE FILAMENT ROIs
		roiManager("deselect"); roiManager("Save", savePath+"//"+id+"_CELL_"+cellIDstr+"_DetectedFilaments.zip"); //save detected filament ROIs
		
		//COLLECT BINARY MASKS (if the option was selected)
		if (saveBinaryMasks == " make_binary")
		{
			selectImage("forR1DG3detection Detected segments"); run("Out [-]"); run("Out [-]"); run("Out [-]"); run("Out [-]"); rename("B1N4RY_"+iCell);
			if (iCell>1) { run("Concatenate...", "  title=B1N4RY_1 open image1=B1N4RY_1 image2=B1N4RY_"+iCell+" image3=[-- None --]"); run("Out [-]"); run("Out [-]"); run("Out [-]"); }
		}
		
		//FIND THE ORIENTATION ANGLES (FERET ANGLES) OF THE FILAMENTS (ONLY LINE ROIs)
		////the length of the longest line between any 2 points of the line ROI is the Feret Distance, and the angle subtended by that line to the horizontal is the Feret Angle
		selectImage("forR1DG3detection");
		roiManager("deselect"); roiManager("Measure");
		selectWindow("Results");
		Angle = Table.getColumn("FeretAngle");
		close("Results");
		
		//FIND THE MIDPOINTS OF THE LINE ROIs
		nROIs = roiManager("count");
		MidPointX = newArray(nROIs);
		MidPointY = newArray(nROIs);
		selectImage("forR1DG3detection");
		for (iROI = 0; iROI < nROIs; iROI++)
		{
			//selectImage("forR1DG3detection");
			roiManager("Select", iROI);
			getSelectionCoordinates(Xpoints, Ypoints);
			sizeROI = lengthOf(Xpoints);
			MidPointX[iROI] = Xpoints[round(sizeROI/2)];
			MidPointY[iROI] = Ypoints[round(sizeROI/2)];
		}
		
		////CALCULATE ALIGNMENT IN THE ORIENTATION (ANGLES) OF THE DETECTED FILAMENTS
		////METHOD: Assume the filaments as unit vectors, calculate dot product (cosine of angle) between the target filament and every neighbouring filament within a distance range, square it to make positive, then average it.
		////DOT PRODUCT:- cos(Angle_1 - Angle_2). After squaring the DOT PRODUCT, final range: 0 (orthogonal/unaligned) to 1 (perfectly aligned)
		sumDotProductSquared = 0;
		numberOfNeighbours = 0;
		AlignmentIndex = newArray(nROIs);
		nNeighboursEvaluated = 1 + round((maxSZnbr-minSZnbr)/stepSizeNbr); //calculate number of neighbourhood sizes for alignment evaluation
		LocalAlignmentIndex = newArray(nROIs*nNeighboursEvaluated);
		NeighbourSizeList = newArray(nNeighboursEvaluated);
		for (iii = 0; iii < nNeighboursEvaluated; iii++) { NeighbourSizeList[iii] = minSZnbr+(iii*stepSizeNbr); }
		
		for (iTarget = 0; iTarget < nROIs; iTarget++)
		{
			sumDotProductSquared = 0;
			numberOfNeighbours = 0;
			//Convert pixels to distance units first
			xT = MidPointX[iTarget]*pixelWidth;
			yT = MidPointY[iTarget]*pixelHeight;
			//run neighbourhood size iterations
			for (szNBR = 0; szNBR < nNeighboursEvaluated; szNBR++)
			{
				//search for neighbours
				for (iNeighbour = 0; iNeighbour < nROIs; iNeighbour++)
				{
					if (iTarget != iNeighbour)
					{
						//Convert pixels to distance units first
						xN = MidPointX[iNeighbour]*pixelWidth;
						yN = MidPointY[iNeighbour]*pixelHeight;
						//compute distance
						distanceFilaments = sqrt( pow((xT-xN),2) + pow((yT-yN),2) );
						//check if it is a neighbour within the size range
						if (distanceFilaments <= NeighbourSizeList[szNBR])
						{
							//CALCULATE DOT PRODUCTS AND SUM THEIR SQUARES
							angleDiff = (Angle[iTarget] - Angle[iNeighbour])*PI/180; //in radians
							sumDotProductSquared = sumDotProductSquared + pow((cos(angleDiff)),2);
							numberOfNeighbours = numberOfNeighbours + 1;
						}
					}
				}
				if (numberOfNeighbours!=0) { LocalAlignmentIndex[iTarget+szNBR*nROIs] = sumDotProductSquared/numberOfNeighbours; }
				else { LocalAlignmentIndex[iTarget+szNBR*nROIs] = NaN; }
				
				//store selected values (when neighbourhood size equals to user defined size)
				if (NeighbourSizeList[szNBR] == mainNEIGHBOURHOODsize) { AlignmentIndex[iTarget] = LocalAlignmentIndex[iTarget+szNBR*nROIs]; }
				
			}
		}
		
		//TABULATE DATA
		selectWindow("FILAMENT_LENGTH"); Table.setColumn("Length_cell_"+cellIDstr, LineLENGTHall);
		selectWindow("FILAMENT_WIDTH"); Table.setColumn("Width_cell_"+cellIDstr, LineWIDTHmeanAll);
		selectWindow("FILAMENT_AREA"); Table.setColumn("AREAfil_cell_"+cellIDstr, LineAREAall);
		selectWindow("FILAMENT_ANGLE"); Table.setColumn("Angle_cell_"+cellIDstr, Angle);
		selectWindow("FILAMENT_ALIGNMENT"); Table.setColumn("Alignment_cell_"+cellIDstr, AlignmentIndex);
		if (chooseNEIGHBOURHOODsizeRANGE == true)
		{
			Table.create("INDIVIDUAL_ALIGNMENTS");
			Table.setLocationAndSize(0, 500, 300, 200, "INDIVIDUAL_ALIGNMENTS");
			for (szNBR = 0; szNBR < nNeighboursEvaluated; szNBR++)
			{
				ColData = Array.slice(LocalAlignmentIndex,szNBR*nROIs,(szNBR*nROIs)+nROIs);
				selectWindow("INDIVIDUAL_ALIGNMENTS"); Table.setColumn("Neighbourhood_size_"+NeighbourSizeList[szNBR]+"_"+DistanceUnit, ColData);
			}
			selectWindow("INDIVIDUAL_ALIGNMENTS");
			saveAs("Text", savePath+"//"+id+"_CELL_"+cellIDstr+"_INDIVIDUAL_FILAMENT_ALIGNMENTS.txt"); close(id+"_CELL_"+cellIDstr+"_INDIVIDUAL_FILAMENT_ALIGNMENTS.txt");
		}
		
		//DRAW FILAMENTS WITH WIDTH AND ALIGNMENT INDICATORS FOR REPRESENTATIVE PURPOSES (if option selected)
		if (drawFilaments == true)
		{
			maxAlignment8bit = 255;
			selectImage("forR1DG3detection"); run("Select None"); run("Duplicate...", "title=FilamentAlignmentIndex");
			selectImage("FilamentAlignmentIndex"); run("Out [-]"); run("Out [-]"); run("Out [-]");
			selectImage("FilamentAlignmentIndex"); run("Remove Overlay"); run("8-bit"); run("Grays"); run("Multiply...", "value=0.0000000 stack");
			for (iROI = 0; iROI < nROIs; iROI++)
			{
				if ((LineWIDTHmeanAll[iROI]>cutoffWIDTH) && (LineLENGTHall[iROI]>cutoffLENGTH))
				{
					lineCOLOR = round(AlignmentIndex[iROI]*maxAlignment8bit);
					setForegroundColor(lineCOLOR, lineCOLOR, lineCOLOR);
					lineWIDTHtoDRAW = round(LineWIDTHmeanAll[iROI]/pixelWidth);
					run("Line Width...", "line="+lineWIDTHtoDRAW);
					selectImage("FilamentAlignmentIndex"); roiManager("Select", iROI); run("Draw", "slice");
				}
			}
			selectImage("FilamentAlignmentIndex"); setMinAndMax(0, maxAlignment8bit); run("Cyan Hot"); run("Invert LUT");
			selectImage("FilamentAlignmentIndex"); rename("FilamentAlignmentIndex_"+iCell);
			if (iCell>1) { run("Concatenate...", "  title=FilamentAlignmentIndex_1 open image1=FilamentAlignmentIndex_1 image2=FilamentAlignmentIndex_"+iCell+" image3=[-- None --]"); run("Out [-]"); run("Out [-]"); run("Out [-]"); }
		}
		//reset ROI parameters to default
		setForegroundColor(0, 0, 0);
		run("Line Width...", "line=1");
		
		close("forR1DG3detection");
		
		//CALCULATE AVERAGE FILAMENT ALIGNMENT AND WIDTH WITHIN THE CELL [THE Array.getStatistics() COMMAND DOES NOT WORK IF NaN VALUES ARE PRESENT, AND CANNOT APPLY CUTOFFS]
		//Array.getStatistics(LineWIDTHmeanAll, minMeanWidth, maxMeanWidth, avgMeanWidth, sDvMeanWidth);
		//Array.getStatistics(AlignmentIndex, minAlignmentIndex, maxAlignmentIndex, avgAlignmentIndex, sDvAlignmentIndex);
		sumWidth = 0;
		countWidth = 0;
		sumAlignment = 0;
		countAlignment = 0;
		for (iROI = 0; iROI < nROIs; iROI++)
		{
			if ((LineWIDTHmeanAll[iROI]>cutoffWIDTH) && (LineLENGTHall[iROI]>cutoffLENGTH))
			{
				if (isNaN(LineWIDTHmeanAll[iROI])==false)
				{
					sumWidth = sumWidth + LineWIDTHmeanAll[iROI];
					countWidth = countWidth + 1;
				}
				if (isNaN(AlignmentIndex[iROI])==false)
				{
					sumAlignment = sumAlignment + AlignmentIndex[iROI];
					countAlignment = countAlignment + 1;
				}
			}
		}
		avgMeanWidth = sumWidth/countWidth;
		avgAlignmentIndex = sumAlignment/countAlignment;
		//CALCULATE STANDARD DEVIATIONS
		sumVarWidth = 0;
		sumVarAlignment = 0;
		for (iROI = 0; iROI < nROIs; iROI++)
		{
			if ((LineWIDTHmeanAll[iROI]>cutoffWIDTH) && (LineLENGTHall[iROI]>cutoffLENGTH))
			{
				if (isNaN(LineWIDTHmeanAll[iROI])==false) { sumVarWidth = sumVarWidth + pow((LineWIDTHmeanAll[iROI] - avgMeanWidth),2); }
				if (isNaN(AlignmentIndex[iROI])==false) { sumVarAlignment = sumVarAlignment + pow((AlignmentIndex[iROI]-avgAlignmentIndex),2); }
			}
		}
		sDvMeanWidth = sqrt(sumVarWidth/countWidth);
		sDvAlignmentIndex = sqrt(sumVarAlignment/countAlignment);
		
		//TABULATE AVERAGED VALUES FOR THE WHOLE CELL AND SAVE LATER
		if (iCell==1)
		{
			print("CELLnumber"+"\t"+"CellArea_SQ"+DistanceUnit+"\t"+"AREAallFilaments_SQ"+DistanceUnit+"\t"+"AvgFilamentWidth_"+DistanceUnit+"\t"+"StDevWidth_"+DistanceUnit+"\t"+"AvgAlignment_within"+mainNEIGHBOURHOODsize+DistanceUnit+"\t"+"StDevAlignment"+"\t"+"NumberOfDetectedFilaments"+"\t"+"NumberOfFilamentsAveragedOver");
		}
		print(iCell+"\t"+AreaCELLS[iCell-1]+"\t"+sumAreaFilaments+"\t"+avgMeanWidth+"\t"+sDvMeanWidth+"\t"+avgAlignmentIndex+"\t"+sDvAlignmentIndex+"\t"+numberSFdetected+"\t"+countWidth);
	}
	
	close("F1L4MENTS");
	selectImage(id); setSlice(1); run("Select None");
	
	//SAVE TABLES
	selectWindow("FILAMENT_LENGTH");
	saveAs("Text", savePath+"//"+id+"_FilamentLENGTHall_"+DistanceUnit+".txt"); close(id+"_FilamentLENGTHall_"+DistanceUnit+".txt");
	selectWindow("FILAMENT_WIDTH");
	saveAs("Text", savePath+"//"+id+"_FilamentWIDTHall_"+DistanceUnit+".txt"); close(id+"_FilamentWIDTHall_"+DistanceUnit+".txt");
	selectWindow("FILAMENT_AREA");
	saveAs("Text", savePath+"//"+id+"_FilamentAREAall_"+DistanceUnit+"Squared.txt"); close(id+"_FilamentAREAall_"+DistanceUnit+"Squared.txt");
	selectWindow("FILAMENT_ANGLE");
	saveAs("Text", savePath+"//"+id+"_FilamentANGLEall.txt"); close(id+"_FilamentANGLEall.txt");
	selectWindow("FILAMENT_ALIGNMENT");
	saveAs("Text", savePath+"//"+id+"_FilamentALIGNMENTall_within"+mainNEIGHBOURHOODsize+DistanceUnit+".txt"); close(id+"_FilamentALIGNMENTall_within"+mainNEIGHBOURHOODsize+DistanceUnit+".txt");
	selectWindow("Log");
	saveAs("Text", savePath+"//"+id+"_allFILAMENTS_AREAavgWIDTHandALIGNMENTwithin"+mainNEIGHBOURHOODsize+DistanceUnit+".txt");
	close("Log");
	
	//PRINT PARAMETERS IN A TEXT FILE FOR CROSS-CHECKING
	print("\\Clear");
	print("RIDGE DETECTION PARAMETERS");
	print("LINE-WIDTH = "+lineWIDTH+"\n"+"High Contrast = "+highCONTRAST+"\n"+"Low Contrast = "+lowCONTRAST+"\n"+"Minimum length = "+minimumLineLENGTHpxls+"\n"+"Maximum length = "+maximumLineLENGTHpxls+"\n"+"Overlap resolution = "+resolveOVERLAP);
	print("\nEstimated parameters:"+"\n"+"SIGMA = "+sigmaRD+"\n"+"Upper Threshold = "+upperTHRESHOLD+"\n"+"Lower Threshold = "+lowerTHRESHOLD+"\n");
	if (extendLINE!="") { print("extend_line APPLIED"); }
	if (correctPOSITION!="") { print("correct_position APPLIED"); }
	print("\nFILTERING PARAMETERS (in pixels):"+"\n"+"Number of filter accumulations = "+nF1LT3Rs+"\n"+"Length of cell edge eroded (in pixels) = "+lengthEDGEerode+"\n"+"Size of neighbourhood considered (in "+DistanceUnit+") = "+mainNEIGHBOURHOODsize);
	if (enhanceLOCALcontrast==true) { print("EnhanceLocalContrast_CLAHE APPLIED"); }
	if (chooseNEIGHBOURHOODsizeRANGE == true) { print("Size range of neighbourhood evaluated (in "+DistanceUnit+"):- Maximum="+maxSZnbr+", Minimum="+minSZnbr+", Step-size_increment="+stepSizeNbr); }
	if (msg2usrWrongNBRsz != "") { print(msg2usrWrongNBRsz+"\nSo the midpoint of the input range was used"); }
	if (ridgeDetectERRORmsg != "") { print("\nRidge Detection failed for_"+ridgeDetectERRORmsg); }
	print("\nFILAMENT_LENGTH_CUTOFF="+"\t"+cutoffLENGTH+"\t"+"in "+DistanceUnit+"\nFILAMENT_WIDTH_CUTOFF="+"\t"+cutoffWIDTH+"\t"+"in "+DistanceUnit);
	saveAs("Text", savePath+"//"+id+"_PARAMETERSused.txt");
	close("Log");
	
	//SAVE BINARY MASKS AND ALIGNMENT INDICATORS AS A STACK (if the option was selected)
	if (saveBinaryMasks == " make_binary")
	{
		selectImage("B1N4RY_1");
		saveAs("Tiff", savePath+"//"+"BinaryMask_"+id+"_DetectedSegments.tif");
		close("BinaryMask_"+id+"_DetectedSegments.tif");
	}
	if (drawFilaments == true)
		{
			selectImage("FilamentAlignmentIndex_1");
			saveAs("Tiff", savePath+"//"+"FilamentALIGNMENT_"+id+"_within"+mainNEIGHBOURHOODsize+DistanceUnit+".tif");
			close("FilamentALIGNMENT_"+id+"_within"+mainNEIGHBOURHOODsize+DistanceUnit+".tif");
		}
}

//*/

//////FUNCTIONS//////

//To accumulate different levels of image filtering operations
function AccumulateFilters(imageName, operation, beginRADIUS, endRADIUS, stepSIZE, FilterMethod) //input image = only single channel image stack, output image = ACCUMULAT3D
{
	//make a duplicate of the input image to work on
	selectImage(imageName); run("Select None"); run("Duplicate...", "title=working1MG duplicate");
	selectImage("working1MG"); run("32-bit"); run("Out [-]"); run("Out [-]"); run("Out [-]"); run("Out [-]");
	nIterations = Math.ceil((abs(endRADIUS-beginRADIUS) + 1)/abs(stepSIZE));
	radiusFILTER = beginRADIUS;
	iFilter = 1;
	while (iFilter<=nIterations)
	{
		selectImage("working1MG"); run("Select None"); run("Duplicate...", "title=F1LT3R_"+iFilter+" duplicate");
		selectImage("F1LT3R_"+iFilter); run("Out [-]"); run("Out [-]"); run("Out [-]");
		//Apply Filters
		if (FilterMethod=="Gaussian Blur") { selectImage("F1LT3R_"+iFilter); run("Select None"); run("Gaussian Blur...", "sigma="+radiusFILTER+" stack"); }
		if (FilterMethod=="Unsharp Mask") { selectImage("F1LT3R_"+iFilter); run("Select None"); run("Unsharp Mask...", "radius="+radiusFILTER+" mask=0.60 stack"); }
		else { selectImage("F1LT3R_"+iFilter); run("Select None"); run(FilterMethod+"...", "radius="+radiusFILTER+" stack"); }
		if (iFilter>1)
		{
			imageCalculator(operation+" create 32-bit stack", "F1LT3R_1","F1LT3R_"+iFilter); close("F1LT3R_1"); close("F1LT3R_"+iFilter);
			selectImage("Result of F1LT3R_1"); rename("F1LT3R_1"); run("Out [-]"); run("Out [-]"); run("Out [-]");
		}
		iFilter = iFilter + 1;
		radiusFILTER = radiusFILTER + stepSIZE;
	}
	close("working1MG");
	selectImage("F1LT3R_1"); rename("ACCUMULAT3D");
}
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