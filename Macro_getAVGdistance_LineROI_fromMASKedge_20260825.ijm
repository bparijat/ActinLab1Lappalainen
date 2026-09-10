//Macro to get the average distance of a line ROI inside a binary mask (value=255) from the mask edge (where 255 meets 0)
//Load the binary mask image of cells and the line ROIs, run macro, follow instructions

id = getTitle();
selectImage(id);
getDimensions(imgWidth, imgHeight, imgChannels, imgSlices, imgFrames);
getVoxelSize(pxlWidth, pxlHeight, pxlDepth, DistanceUnit);

operationalMASKimg = "M45K"; //mask image to operate on
TabDISTANCES = "DISTANCES"; //Table to display distances
if (isOpen(operationalMASKimg)==true) { close(operationalMASKimg); }
if (isOpen(TabDISTANCES)==true) { close(TabDISTANCES); }

//check if ROIs are added and they are valid line ROIs
roiManager("Deselect");
roiManager("Show None");
nROIs = roiManager("count");
if (nROIs==0) { exit("No ROIs in ROI Manager. Add and run code again."); }
ValidLineROIs = newArray(nROIs);
Array.fill(ValidLineROIs, 0);
countValidLines = 0;
for (iROI = 0; iROI < nROIs; iROI++)
{
	selectImage(id); roiManager("Select", iROI);
	ROItype = Roi.getType;
	if ((ROItype=="line")||(ROItype=="polyline")||(ROItype=="freeline"))
	{
		ValidLineROIs[iROI] = 1;
		countValidLines = countValidLines + 1;
	}
	else { roiManager("Rename", "not-line-ROI"); }
}
if (countValidLines==0) { exit("No valid LINE ROIs in ROI Manager. Add them and run code again."); }
roiManager("Deselect");

ConfirmSTRINGimg = "MASK image name: " + id;
ConfirmSTRINGroi = "Line ROIs: " + countValidLines + " out of " + nROIs;
nChannels = 3; //number of channels of the image where line ROIs were made
Dialog.createNonBlocking("Parameters...");
Dialog.setLocation(0,0);
Dialog.addMessage(ConfirmSTRINGimg + "\n" + ConfirmSTRINGroi, 12, "blue");
Dialog.addMessage("If the original image where line ROIs were created had multiple channels, line ROI slice numbers may not match MASK slices", 14, "magenta");
Dialog.addNumber("To compensate, give the number of channels in the original image for Line ROIs", nChannels);
Dialog.show();
nChannels = Dialog.getNumber();

setBatchMode(true);
run("Collect Garbage");
//Create a separate binary mask image to operate on
if (nChannels>1)
{
	if (isOpen("Merged")==true) { close("Merged"); }
	if (isOpen("Composite")==true) { close("Composite"); }
	mergeSTR="";
	for (iCh = 1; iCh<=nChannels; iCh++)
	{
		selectImage(id); run("Select None"); run("Duplicate...", "title=c"+iCh+" duplicate");
		mergeSTR = mergeSTR+"c"+iCh+"="+"c"+iCh+" ";
	}
	run("Merge Channels...", mergeSTR+"create");
	if (isOpen("Merged")==true) { selectImage("Merged"); rename(operationalMASKimg); }
	if (isOpen("Composite")==true) { selectImage("Composite"); rename(operationalMASKimg); }
}
if (nChannels==1)
{
	selectImage(id); run("Select None"); run("Duplicate...", "title=M45K duplicate");
}

//find the minimum distance of each point of the line ROI from the mask edge and average them
LineLengths = newArray(nROIs);
AVGdist = newArray(nROIs);
for (iROI = 0; iROI < nROIs; iROI++)
{
	//use a point on the line ROI to detect binary mask edges
	selectImage(operationalMASKimg);
	roiManager("Select", iROI);
	run("Interpolate");
	getSelectionCoordinates(XlineROI, YlineROI);
	lenLineROIxy = lengthOf(XlineROI);
	//use the Wand tool to get the mask edges as a selection
	midPointLine = round(lenLineROIxy/2);
	midPointLineVAL = -1;
	validPointSearchRad = round(lenLineROIxy/10);
	pointSearch = midPointLine-validPointSearchRad; //to search for a point on the line ROI around the midpoint whose pixel value = 255, in case there is a dark pixel on the line
	xWand = 0;
	yWand = 0;
	while (midPointLineVAL==(-1))
	{
		selectImage(operationalMASKimg);
		if ((pointSearch>0)&&(pointSearch<lenLineROIxy))
		{
			midPointLineVAL = getPixel(XlineROI[pointSearch], YlineROI[pointSearch]);
			pointSearch = pointSearch+1;
		}
	}
	doWand(XlineROI[pointSearch], YlineROI[pointSearch]);
	getSelectionCoordinates(XedgeROI, YedgeROI);
	lenEdgeROIxy = lengthOf(XedgeROI);
	//find the minimum distance of each point of the line ROI from the mask edge
	lineDISTsum = 0;
	countLinePoints = 0;
	for (iLine = 0; iLine<lenLineROIxy; iLine++)
	{
		minDIST = pow(imgWidth*pxlWidth*imgHeight*pxlHeight,2);
		xLine = XlineROI[iLine];
		yLine = YlineROI[iLine];
		for (iEdge = 0; iEdge<lenEdgeROIxy; iEdge++)
		{
			sqDIST = pow((xLine-XedgeROI[iEdge])*pxlWidth,2) + pow((yLine-YedgeROI[iEdge])*pxlHeight,2);
			if (sqDIST<minDIST) { minDIST=sqDIST; }
		}
		lineDISTsum = lineDISTsum + minDIST;
		countLinePoints = countLinePoints + 1;
	}
	AVGdist[iROI] = lineDISTsum/countLinePoints;
	LineLengths[iROI] = "roi"+(iROI+1)+"_"+(lenLineROIxy*pxlWidth)+"_"+DistanceUnit;
}
close(operationalMASKimg);
run("Collect Garbage");
setBatchMode(false);

Table.create(TabDISTANCES);
Table.setLocationAndSize(0, 0, 350, 700);
Table.setColumn("lineROI_length", LineLengths);
Table.setColumn("Distance_from_edge", AVGdist);