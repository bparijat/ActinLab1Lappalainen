//Macro to get Line Profile values for all ROIs in all channels and normalize them by min-max or mean value, and perform Periodicity analysis if chosen
/*
 * Draw line ROIs (straight, segmented, or freehand) on the objects of interest in the image, and add to ROI Manager
 * Click on the image on which ROIs are drawn, run the Macro
 */

run("Set Measurements...", "area mean standard modal min centroid center perimeter fit shape feret's integrated median redirect=None decimal=9");

id = getTitle();
fPath = getDirectory("image");
imname = File.getNameWithoutExtension(id);
getDimensions(imgWidth, imgHeight, imgChannels, imgSlices, imgFrames);
getVoxelSize(pxlWidth, pxlHeight, pxlDepth, DistanceUnit);

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
if (countValidLines==0) { exit("No valid LINE ROIs in ROI Manager. Add and run code again."); }
roiManager("Deselect");

ConfirmSTRINGimg = "IMAGEname: " + id;
ConfirmSTRINGroi = "Line ROIs: " + countValidLines + " out of " + nROIs;
widthLine = 5; //in pixels
saveRESULTStables = true;
doDTR = false;
windowDETRNDsz = 3; //in microns or physical distance unit
doACF = true;
avgAdjacentPoints = 3;
doCCF = true;
doFHT = true;
Dialog.createNonBlocking("Specify Line Width for intensity profile measurements");
Dialog.setLocation(0,0);
Dialog.addMessage(ConfirmSTRINGimg + "\n" + ConfirmSTRINGroi, 12, "blue");
Dialog.addMessage("Straight, Segmented, and Freehand lines allowed", 14, "blue");
Dialog.addMessage("For all the line ROIs in ROI Manager...", 14, "magenta");
Dialog.addNumber("Line thickness (in pixels)", widthLine);
Dialog.addMessage("");
Dialog.addMessage("Perform Signal Periodicity analysis... \nUsing Zero-Mean Unit-SD normalized intensity values...", 16, "blue");
Dialog.addCheckbox("Apply DeTRENDING (Piece-wise, sliding-window)", doDTR);
Dialog.addMessage("DeTRENDING removes baseline intensity trends (like background haze, Z-shifts)", 12, "red");
Dialog.addMessage("Baseline trends can mess up signal periodicity analysis... \nPiece-wise DeTRENDING subtracts an average intensity value within a \n''window'' of sequential points (along the line). \nThe window-size must be in a physical distance unit, unless the image has none... \nThen the window-size should be given in pixels", 12, "black");
Dialog.addMessage("Ideally, the window-size should be smaller than the line ROI length, \nBUT larger than 20% of the line length", 12, "red");
Dialog.addNumber("Window-size for piece-wise DeTRENDING (in Microns/PhysicalUnit)", windowDETRNDsz);
Dialog.addMessage("Modes of Periodicity analysis...",16,"blue");
Dialog.addCheckbox("Intensity Auto-Correlation Function (ACF)", doACF);
Dialog.addNumber("For noise-free ACF peak detection, number of points for adjacent averaging?", avgAdjacentPoints);
Dialog.addCheckbox("Intensity Cross-Correlation Function (CCF), for multi-channel images only", doCCF);
Dialog.addCheckbox("Fourier Transform (FHT) to extract peak-occurence frequency", doFHT);
Dialog.addMessage("FHT --> 1D Fast Hartley Transform with Hann window \nIdeally, the intensities should decay at both end-points of the line", 12, "black");
Dialog.addMessage("To JUST VIEW the results in a Table format, and NOT SAVE...", 14, "blue");
Dialog.addCheckbox("UNCHECK this box (to NOT SAVE results)", saveRESULTStables);
Dialog.show();
widthLine = Dialog.getNumber();
doDTR = Dialog.getCheckbox();
windowDETRNDsz = Dialog.getNumber();
doACF = Dialog.getCheckbox();
avgAdjacentPoints = Dialog.getNumber();
doCCF = Dialog.getCheckbox();
doFHT = Dialog.getCheckbox();
saveRESULTStables = Dialog.getCheckbox();

if ((saveRESULTStables==true)&&(fPath=="")) { fPath = getDirectory("Browse to a location to save files"); }

//define tables to store data
TableNames = newArray("ProfilePerROI","ProfilePerCHN","Norm_0to1","Norm_Mean","Norm_mean0sd1");
nMainTables = lengthOf(TableNames);
TabDETREND = "DETRENDED";
TabACFcoef = "ACFcoeff";
TabACFvals = "ACFvalues";
TabACFper = "ACFperiodicity";
TabFOURIERx = "FourierX";
TabFOURIERy = "FourierY";
TabFOURIERxy = "FHT";
TabFOURIERper = "FHTperiodicity";
TabCCFcoef = "CCFcoeff";
TabCCFvals = "CCFvals";
//define table display sizes
scrW = screenWidth;
scrH = screenHeight;
scrHdisplay = scrH*(round(nMainTables/2))/nMainTables;
tableW = round(scrW/10);
tableH = round(scrHdisplay/nMainTables);
//close tables if opened previously
for (i = 0; i < nMainTables; i++)
{
	if (isOpen(TableNames[i])==true) { close(TableNames[i]); }
}
if (isOpen(TabDETREND)==true) { close(TabDETREND); }
if (isOpen(TabACFcoef)==true) { close(TabACFcoef); }
if (isOpen(TabACFvals)==true) { close(TabACFvals); }
if (isOpen(TabACFper)==true) { close(TabACFper); }
if (isOpen(TabFOURIERx)==true) { close(TabFOURIERx); }
if (isOpen(TabFOURIERy)==true) { close(TabFOURIERy); }
if (isOpen(TabFOURIERxy)==true) { close(TabFOURIERxy); }
if (isOpen(TabFOURIERper)==true) { close(TabFOURIERper); }
if (isOpen(TabCCFcoef)==true) { close(TabCCFcoef); }
if (isOpen(TabCCFvals)==true) { close(TabCCFvals); }
//create table to store raw-data from line scans
i=0;
Table.create(TableNames[i]);
Table.setLocationAndSize(0, i*tableH, tableW, tableH);

//get Line Profiles
setBatchMode(true);
nPointsPerLine = newArray(nROIs);
Array.fill(nPointsPerLine, 0);
for (iROI = 0; iROI < nROIs; iROI++)
{
	if (ValidLineROIs[iROI]==1)
	{
		for (ch = 1; ch <= imgChannels; ch++)
		{
			selectImage(id);
			roiManager("Select", iROI);
			Roi.setStrokeWidth(widthLine);
			Stack.setChannel(ch);
			run("Plot Profile"); //not using getProfile() function as this captures ImageJ's native distance interpolation
			Plot.getValues(Distance, Intensity);
			//close images whose name starts with "Plot of ..." to avoid capturing wrong line profiles (images with large file names get truncated in the "Plot of ..." name)
			OpenIMGs = getList("image.titles");
			nOpenIMGs = lengthOf(OpenIMGs);
			for (iOpen = 0; iOpen<nOpenIMGs; iOpen++)
			{
				if (startsWith(OpenIMGs[iOpen], "Plot of ")==true) { close(OpenIMGs[iOpen]); }
			}
			nPointsPerLine[iROI] = lengthOf(Distance); //store the number of data points per line for trimming arrays later
			//save the distance information in the first column of the table
			if (ch == 1)
			{
				selectWindow(TableNames[0]);
				Table.setColumn("roi"+(iROI+1)+"_Dist("+DistanceUnit+")", Distance);
			}
			//tabulate the raw intensity values (ImageJ actually averages the pixel intensities along the line width, so it's not exactly raw in the true sense)
			selectWindow(TableNames[0]);
			Table.setColumn("roi"+(iROI+1)+"c"+ch+"_Int", Intensity);
		}
	}
}
setBatchMode(false);
selectImage(id); run("Select None"); setSlice(1);

//find max points per line
maxPointsPerLine = 0;
maxPointsPerLineID = 0;
for (iPP = 0; iPP<nROIs; iPP++)
{
	if (nPointsPerLine[iPP]>maxPointsPerLine)
	{
		maxPointsPerLine = nPointsPerLine[iPP];
		maxPointsPerLineID = iPP;
	}
}

//create tables to store the calculated data
hT = 0;
for (i = 1; i < nMainTables; i++)
{
	if ((i%2)!=0) { hT = hT+1; }
	Table.create(TableNames[i]);
	Table.setLocationAndSize((1-(i%2))*tableW, (hT+0)*tableH, tableW, tableH);
}
if (doDTR==true)
{
	Table.create(TabDETREND);
	Table.setLocationAndSize(2*tableW, (hT+0)*tableH, tableW, tableH);
}
if (doACF==true)
{
	Table.create(TabACFcoef);
	Table.setLocationAndSize(0*tableW, (hT+1)*tableH, tableW, tableH);
	Table.create(TabACFvals);
	Table.setLocationAndSize(0*tableW, (hT+1)*tableH, tableW, tableH);
	Table.create(TabACFper);
	Table.setLocationAndSize(1*tableW, (hT+1)*tableH, tableW, tableH);
}
if (doCCF==true)
{
	Table.create(TabCCFcoef);
	Table.setLocationAndSize(2*tableW, (hT+1)*tableH, tableW, tableH);
	Table.create(TabCCFvals);
	Table.setLocationAndSize(2*tableW, (hT+1)*tableH, tableW, tableH);
}
if (doFHT==true)
{
	Table.create(TabFOURIERx);
	Table.setLocationAndSize(0*tableW, (hT+2)*tableH, tableW, tableH);
	Table.create(TabFOURIERy);
	Table.setLocationAndSize(0*tableW, (hT+2)*tableH, tableW, tableH);
	Table.create(TabFOURIERxy);
	Table.setLocationAndSize(0*tableW, (hT+2)*tableH, tableW, tableH);
	Table.create(TabFOURIERper);
	Table.setLocationAndSize(1*tableW, (hT+2)*tableH, tableW, tableH);
}

//first, save distances separately for raw and normalized intensities (for ease of averaging in spreadsheets later)
for (iROI = 0; iROI < nROIs; iROI++)
{
	if (ValidLineROIs[iROI]==1)
	{
		selectWindow(TableNames[0]);
		Distance = Table.getColumn("roi"+(iROI+1)+"_Dist("+DistanceUnit+")");
		lenVALs = nPointsPerLine[iROI]; //knowing the number of data points per line helps to trim away NaN values later
		Distance = Array.trim(Distance, lenVALs);
		for (iTable = 1; iTable < nMainTables; iTable++)
		{
			selectWindow(TableNames[iTable]);
			Table.setColumn("roi"+(iROI+1)+"_Dist("+DistanceUnit+")", Distance);
		}
	}
}

//perform normalizations and other calculations, store in tables
for (ch = 1; ch <= imgChannels; ch++)
{
	if (doACF==true)
	{
		ACFlineROIcheck = newArray(nROIs);
		ACFperiodicity = newArray(nROIs);
		ACFprominence = newArray(nROIs);
	}
	if (doFHT==true)
	{
		FHTlineROIcheck = newArray(nROIs);
		FHTperiodicity = newArray(nROIs);
	}
	for (iROI = 0; iROI < nROIs; iROI++)
	{
		if (ValidLineROIs[iROI]==1)
		{
			selectWindow(TableNames[0]);
			Distance = Table.getColumn("roi"+(iROI+1)+"_Dist("+DistanceUnit+")");
			Intensity = Table.getColumn("roi"+(iROI+1)+"c"+ch+"_Int");
			
			//remove NaNs coming from the Table columns
			lenVALs = nPointsPerLine[iROI];
			Distance = Array.trim(Distance, lenVALs);
			Intensity = Array.trim(Intensity, lenVALs);
			
			//save raw intensity trends before Detrending alters values, if applied
			selectWindow(TableNames[1]);
			Table.setColumn("c"+ch+"roi"+(iROI+1)+"_INTmeasured", Intensity);
			
			//perfrom SLIDING-WINDOW PIECE-WISE DeTRENDING
			if (doDTR==true)
			{
				windowDETRNDszPXL = round(windowDETRNDsz/pxlWidth);
				windowDETRNDszPXLhalf = floor(windowDETRNDszPXL/2);
				ValDETRENDED = newArray(lenVALs);
				if (lenVALs>windowDETRNDszPXL)
				{
					for (iDT1=0; iDT1<lenVALs; iDT1++)
					{
						//find Begin and End-points of the sliding window
						iBeg = iDT1 - windowDETRNDszPXLhalf;
						iEnd = iDT1 + windowDETRNDszPXLhalf;
						if (iBeg<0)
						{
							shift = abs(0-iBeg);
							iBeg = iBeg + shift;
							iEnd = iEnd + shift;
						}
						if (iEnd>lenVALs)
						{
							shift = abs(lenVALs-iEnd);
							iBeg = iBeg - shift;
							iEnd = iEnd - shift;
						}
						//calculate mean intensity of the window
						windowVAL = 0;
						windowVALcount = 0;
						for (iDT2=iBeg; iDT2<iEnd; iDT2++)
						{
							windowVAL = windowVAL + Intensity[iDT2];
							windowVALcount = windowVALcount + 1;
						}
						windowVAL = windowVAL/windowVALcount;
						ValDETRENDED[iDT1] = Intensity[iDT1] - windowVAL;
					}
					selectWindow(TabDETREND);
					Table.setColumn("c"+ch+"roi"+(iROI+1)+"_DETRENDED", ValDETRENDED);
					
					//replace the Intensity values with DeTRENDed intensities
					for (iDT1=0; iDT1<lenVALs; iDT1++) { Intensity[iDT1] = ValDETRENDED[iDT1]; }
				}
			}
			
			//normalize intensity values and tabulate
			Array.getStatistics(Intensity, intMIN, intMAX, intMEAN, intStdDev);
			ValNORM0to1 = newArray(lenVALs);
			Array.fill(ValNORM0to1, 0);
			ValNORMmean = newArray(lenVALs);
			Array.fill(ValNORMmean, 0);
			ValNORMmean0sd1 = newArray(lenVALs);
			Array.fill(ValNORMmean0sd1, 0);
			for (iVal = 0; iVal < lenVALs; iVal++)
			{
				ValNORM0to1[iVal] = (Intensity[iVal]-intMIN)/(intMAX-intMIN); //for min-max normalization to 0-1
				ValNORMmean[iVal] = (Intensity[iVal])/(intMEAN); //for normalization by the mean value
				if ((intStdDev==0)||(isNaN(intStdDev)==true)) { intStdDev = 1; } //to avoid division errors
				ValNORMmean0sd1[iVal] = (Intensity[iVal]-intMEAN)/intStdDev; //to make 0-mean 1-sd normalization
			}
			selectWindow(TableNames[2]);
			Table.setColumn("c"+ch+"roi"+(iROI+1)+"_Norm0to1", ValNORM0to1);
			selectWindow(TableNames[3]);
			Table.setColumn("c"+ch+"roi"+(iROI+1)+"_NormMEAN", ValNORMmean);
			
			//save the 0-mean 1-sd normalized intensity arrays (with/without detrending, as specified)
			selectWindow(TableNames[4]);
			Table.setColumn("c"+ch+"roi"+(iROI+1)+"_mean0sd1", ValNORMmean0sd1);
			
			//perform intensity auto-correlation using the 0-Mean 1-sd normalized intensity values (with/without detrending)
			//using the 0-Mean 1-sd normalized intensity values gives Pearson's correlation coefficient
			if (doACF==true)
			{
				////the function performs auto-correlation if both input arrays are exactly the same
				getCorrCoeff(ValNORMmean0sd1,ValNORMmean0sd1); //the function gives 2 arrays as output: LagVALs and CorrVAL in a Table called "CorrelationCoefficients"
				selectWindow("CorrelationCoefficients");
				LagDISTpt = Table.getColumn("LagVALs");
				CoeffACF = Table.getColumn("CorrVAL");
				close("CorrelationCoefficients");
				
				//convert LagVALs to actual physical distances
				szCorr = lengthOf(LagDISTpt);
				LagDIST = newArray(szCorr);
				for (iLag = 0; iLag < szCorr; iLag++)
				{
					lagValueABS = abs(LagDISTpt[iLag]);
					if ((lagValueABS>0)&&(isNaN(lagValueABS)==false)) //avoiding division-by-0 errors
					{
						lagValueSIG = (LagDISTpt[iLag])/abs(LagDISTpt[iLag]);
					}
					else { lagValueSIG=0; }
					LagDIST[iLag] = lagValueSIG*Distance[lagValueABS];
				}
				
				//get periodicity value from the calculated ACF
				//input the 1D array of ACF, its corresponding lag value array, and the number of adjacent points for averaging, so that noisy small peaks are avoided
				//ouput is an array, first element is the periodicity, which is the lag location of the secondary peak, second element is the peak prominence
				PeriodicityACF = getACFperiodicity(CoeffACF, LagDIST, avgAdjacentPoints);
				lineLENGTHstr = "roi"+(iROI+1)+"_"+Distance[(lenVALs-1)];
				ACFlineROIcheck[iROI] = lineLENGTHstr;
				ACFperiodicity[iROI] = PeriodicityACF[0];
				ACFprominence[iROI] = PeriodicityACF[1];
				
				//display data in Tables
				if ((iROI==maxPointsPerLineID)&&(ch==1))
				{
					selectWindow(TabACFcoef);
					Table.setColumn("lagDist("+DistanceUnit+")", LagDIST);
				}
				selectWindow(TabACFvals);
				Table.setColumn("c"+ch+"roi"+(iROI+1)+"_ACF", CoeffACF);
			}
			
			//perform Fourier transform on the the 0-Mean 1-sd normalized intensity values (with/without detrending)
			//using 0-Mean 1-sd normalized intensity values gets rid of the whole line's intensity magnitude (occuring at Frequency=0, called DC-offset in Signal Processing)
			//thus, the frequency at maximum amplitude corresponds to the periodicity
			if (doFHT==true)
			{
				//function to perform 1D Fast Hartley Transform using ImageJ's function- Array.fourier(FHTinput, FHTwindowTYPE)
				getFHT(ValNORMmean0sd1,"Hann"); //the function gives 2 arrays as output: FHTfreq and FHTrmsAMP in a Table called "FFTvals"
				physicalDistanceStepSize = Distance[1] - Distance[0]; //instead of using pxlWidth or pxlHeight as they may not be consistent (e.g. in kymographs and resliced images)
				selectWindow("FFTvals");
				FHTx = Table.getColumn("FHTfreq");
				FHTy = Table.getColumn("FHTrmsAMP");
				close("FFTvals");
				
				//Scale the frequency array (FHTx) to physical units
				lenFHT = lengthOf(FHTx);
				for (iPer = 0; iPer < lenFHT; iPer++)
				{
					FHTx[iPer] = FHTx[iPer]/physicalDistanceStepSize;
				}
				
				//compute periodicity
				maxFHTamp = -999999;
				periodicityVAL = 0;
				for (iPer = 0; iPer < lenFHT; iPer++)
				{
					if (FHTy[iPer]>maxFHTamp)
					{
						maxFHTamp = FHTy[iPer];
						if (FHTx[iPer]>0) { periodicityVAL = 1/FHTx[iPer]; }
						else { periodicityVAL = 0; }
					}
				}
				lineLENGTHstr = "roi"+(iROI+1)+"_"+Distance[(lenVALs-1)];
				FHTlineROIcheck[iROI] = lineLENGTHstr;
				FHTperiodicity[iROI] = periodicityVAL;
				
				//display data in Tables
				if (ch == 1)
				{
					selectWindow(TabFOURIERx);
					Table.setColumn("roi"+(iROI+1)+"_Freq("+DistanceUnit+"_INV)", FHTx);
				}
				selectWindow(TabFOURIERy);
				Table.setColumn("c"+ch+"roi"+(iROI+1)+"_FHTamp", FHTy);
			}
		}
	}
	if (doACF==true)
	{
		selectWindow(TabACFper);
		if (ch==1)
		{
			Table.setColumn("LineLength("+DistanceUnit+")", ACFlineROIcheck);
		}
		Table.setColumn("c"+ch+"ACFperiodicity("+DistanceUnit+")", ACFperiodicity);
		Table.setColumn("c"+ch+"ACFpeakProminence", ACFprominence);
	}
	if (doFHT==true)
	{
		selectWindow(TabFOURIERper);
		if (ch==1)
		{
			Table.setColumn("LineLength("+DistanceUnit+")", FHTlineROIcheck);
		}
		Table.setColumn("c"+ch+"FHTperiodicity("+DistanceUnit+")", FHTperiodicity);
	}
}

//compile all ACF values into 1 table
if (doACF==true)
{
	for (ch = 1; ch <= imgChannels; ch++)
	{
		for (iROI = 0; iROI < nROIs; iROI++)
		{
			if (ValidLineROIs[iROI]==1)
			{
				selectWindow(TabACFvals);
				ACFval = Table.getColumn("c"+ch+"roi"+(iROI+1)+"_ACF");
				selectWindow(TabACFcoef);
				Table.setColumn("c"+ch+"roi"+(iROI+1)+"_ACF", ACFval);
			}
		}
	}
	close(TabACFvals);
}

//compile all FHT values into 1 table
if (doFHT==true)
{
	for (iROI = 0; iROI < nROIs; iROI++)
	{
		if (ValidLineROIs[iROI]==1)
		{
			for (ch = 1; ch <= imgChannels; ch++)
			{
				if (ch==1)
				{
					selectWindow(TabFOURIERx);
					FHTf = Table.getColumn("roi"+(iROI+1)+"_Freq("+DistanceUnit+"_INV)");
					selectWindow(TabFOURIERxy);
					Table.setColumn("roi"+(iROI+1)+"_Freq("+DistanceUnit+"_INV)", FHTf);
				}
				selectWindow(TabFOURIERy);
				FHTa = Table.getColumn("c"+ch+"roi"+(iROI+1)+"_FHTamp");
				selectWindow(TabFOURIERxy);
				Table.setColumn("roi"+(iROI+1)+"c"+ch+"_FHTamp", FHTa);
			}
		}
	}
	close(TabFOURIERx);
	close(TabFOURIERy);
}

//Compute CCF (Cross-Correlation Function) with the 0-Mean 1-sd normalized intensity values
//using the 0-Mean 1-sd normalized intensity values gives Pearson's correlation coefficient
/////EXTRACTING DATA FROM THE TABLE COLUMNS AUTOMATICALLY ALIGNS THE 0-lag OF THE ARRAYS, BECAUSE ALL COLUMNS IN THE TABLE ARE PADDED WITH NaN WHEN ROWS ARE EMPTY/////
if (imgChannels>1)
{
	if (doCCF==true)
	{
		nCCFpairs = imgChannels*(imgChannels-1)/2; //for N channels, number of unique pairs = N! / (2! * (N-2)!)
		//Generate Arrays to store channel numbers for every unique pairs (combination order ignored)
		CCFch1 = newArray(nCCFpairs);
		CCFch2 = newArray(nCCFpairs);
		iCCFpair = 0;
		for (ch1 = 1; ch1 <= imgChannels; ch1++)
		{
			for (ch2 = (ch1+1); ch2 <= imgChannels; ch2++)
			{
				CCFch1[iCCFpair] = ch1;
				CCFch2[iCCFpair] = ch2;
				iCCFpair = iCCFpair + 1;
			}
		}
		//Compute CCF with every unique pairs of channels (combination order ignored)
		for (iROI = 0; iROI < nROIs; iROI++)
		{
			if (ValidLineROIs[iROI]==1)
			{
				selectWindow(TableNames[4]);
				Distance = Table.getColumn("roi"+(iROI+1)+"_Dist("+DistanceUnit+")");
				for (iCCFpair = 0; iCCFpair < nCCFpairs; iCCFpair++)
				{
					ch1 = CCFch1[iCCFpair];
					ch2 = CCFch2[iCCFpair];
					selectWindow(TableNames[4]);
					IntC1 = Table.getColumn("c"+ch1+"roi"+(iROI+1)+"_mean0sd1");
					IntC2 = Table.getColumn("c"+ch2+"roi"+(iROI+1)+"_mean0sd1");
					//perform Cross-Correlation
					getCorrCoeff(IntC1,IntC2); //the function gives 2 arrays as output: LagVALs and CorrVAL in a Table called "CorrelationCoefficients"
					selectWindow("CorrelationCoefficients");
					LagDISTpt = Table.getColumn("LagVALs");
					CoeffCCF = Table.getColumn("CorrVAL");
					close("CorrelationCoefficients");
					//convert LagVALs to actual physical distances
					szCorr = lengthOf(LagDISTpt);
					LagDIST = newArray(szCorr);
					for (iLag = 0; iLag < szCorr; iLag++)
					{
						lagValueABS = abs(LagDISTpt[iLag]);
						if ((lagValueABS>0)&&(isNaN(lagValueABS)==false)) //avoiding division-by-0 errors
						{
							lagValueSIG = (LagDISTpt[iLag])/abs(LagDISTpt[iLag]);
						}
						else { lagValueSIG=0; }
						LagDIST[iLag] = lagValueSIG*Distance[lagValueABS];
					}
					//store data in Tables
					if (iROI==maxPointsPerLineID)
					{
						selectWindow(TabCCFcoef);
						Table.setColumn("lagDist("+DistanceUnit+")", LagDIST);
					}
					selectWindow(TabCCFvals);
					Table.setColumn("roi"+(iROI+1)+"_CCF"+"c"+ch1+"c"+ch2, CoeffCCF);
				}
			}
		}
		//copy and paste the CCF values into a single table
		for (iCCFpair = 0; iCCFpair < nCCFpairs; iCCFpair++)
		{
			ch1 = CCFch1[iCCFpair];
			ch2 = CCFch2[iCCFpair];
			for (iROI = 0; iROI < nROIs; iROI++)
			{
				if (ValidLineROIs[iROI]==1)
				{
					selectWindow(TabCCFvals);
					CCFvals = Table.getColumn("roi"+(iROI+1)+"_CCF"+"c"+ch1+"c"+ch2);
					selectWindow(TabCCFcoef);
					Table.setColumn("CCF"+"c"+ch1+"c"+ch2+"_roi"+(iROI+1), CCFvals);
				}
			}
		}
		close(TabCCFvals);
	}
}


//save ROIs and Data
if (saveRESULTStables==true)
{
	saveDir = fPath + "Lines_" + id + "_All";
	File.makeDirectory(saveDir);
	roiManager("Deselect");
	roiManager("Save", saveDir+ "//" + id + "_LineROIs.zip");
	lineWtxt = "_LINEw"+widthLine+"px_";
	for (i = 0; i < nMainTables; i++)
	{
		selectWindow(TableNames[i]);
		fNameTXT = imname + lineWtxt + TableNames[i] + ".txt";
		saveAs("Results", saveDir+ "//" + fNameTXT);
		close(fNameTXT);
	}
	if (doDTR==true)
	{
		selectWindow(TabDETREND);
		fNameTXT = imname + lineWtxt + "Sz"+windowDETRNDsz+DistanceUnit + "_DeTRND.txt";
		saveAs("Results", saveDir+ "//" + fNameTXT);
		close(fNameTXT);
		close(TabDETREND);
	}
	if (doACF==true)
	{
		selectWindow(TabACFcoef);
		fNameTXT = imname + lineWtxt + TabACFcoef + ".txt";
		saveAs("Results", saveDir+ "//" + fNameTXT);
		close(fNameTXT);
		close(TabACFcoef);
		selectWindow(TabACFper);
		fNameTXT = imname + lineWtxt + TabACFper + ".txt";
		saveAs("Results", saveDir+ "//" + fNameTXT);
		close(fNameTXT);
		close(TabACFper);
	}
	if (doCCF==true)
	{
		selectWindow(TabCCFcoef);
		fNameTXT = imname + lineWtxt + TabCCFcoef + ".txt";
		saveAs("Results", saveDir+ "//" + fNameTXT);
		close(fNameTXT);
		close(TabCCFcoef);
	}
	if (doFHT==true)
	{		
		selectWindow(TabFOURIERxy);
		fNameTXT = imname + lineWtxt + TabFOURIERxy + ".txt";
		saveAs("Results", saveDir+ "//" + fNameTXT);
		close(fNameTXT);
		close(TabFOURIERxy);
		selectWindow(TabFOURIERper);
		fNameTXT = imname + lineWtxt + TabFOURIERper + ".txt";
		saveAs("Results", saveDir+ "//" + fNameTXT);
		close(fNameTXT);
		close(TabFOURIERper);
	}
	
	exit("Data saved in: \n"+saveDir);
}

//////FUNCTIONS//////

//function to perform cross-correlation analysis between two 1D functions (arrays ArrayY1 and ArrayY2)
//performs auto-correlation if both input arrays are exactly the same
function getCorrCoeff(ArrayY1,ArrayY2) //the function gives 2 arrays as output: LagVALs and CorrVAL in a Table called "CorrelationCoefficients"
{
	szArrayY1 = lengthOf(ArrayY1);
	szArrayY2 = lengthOf(ArrayY2);
	//stopping if both arrays don't have the same length
	if (szArrayY1!=szArrayY2)
	{
		exit("ERROR: input Arrays for correlation calculation have different sizes!");
	}
	szCC = szArrayY1;
	
	// Check if performing Autocorrelation (both input Arrays are absolutely identical)
    isAutoCorr = true;
    for (iINP = 0; iINP < szCC; iINP++)
    {
        if (ArrayY1[iINP] != ArrayY2[iINP])
        {
            isAutoCorr = false; // mismatch between elements, performing Cross-Correlation
            break;
        }
    }
    
	minLag = 0;
    if (isAutoCorr==false) { minLag = (-1)*(szCC - 1); }
    maxLag = (1)*(szCC - 1);
    
	numLAGs = abs(minLag)+1+abs(maxLag); //+1 to account for 0, because range of lag = -(szCC-1) to 0 to +(szCC-1), and because for an array of size szCC, indices range from 0 to szCC-1
	LagVALs = newArray(numLAGs);
	CorrVAL = newArray(numLAGs);
	
	//Correlation coefficient calculation
	for (iLag = minLag; iLag <= maxLag; iLag++)
	{
		LagVALs[iLag+abs(minLag)] = iLag;
		
		countNumOfProducts = 0;
		sumOfProducts = 0;
		for (iP = 0; iP < szCC; iP++)
		{
			i1 = iP;
			i2 = i1+iLag;
			
			if ((i2>=0)&&(i2<szCC))
			{
				if ((isNaN(ArrayY2[i2])!=true)&&(isNaN(ArrayY1[i1])!=true))
				{
					sumOfProducts = sumOfProducts + ((ArrayY2[i2])*(ArrayY1[i1]));
					countNumOfProducts = countNumOfProducts + 1;
				}
			}
		}
		if (countNumOfProducts>0)
		{
			CorrVAL[iLag+abs(minLag)] = sumOfProducts/countNumOfProducts;
		}
		else
		{
			CorrVAL[iLag+abs(minLag)] = 0;
		}
	}
	if (isAutoCorr==true)
	{
		//normalize the ACF so that value at 0 lag = 1
		if ((CorrVAL[0]!=0)&&(isNaN(CorrVAL[0])==false))
		{
			corrCoeffAt0 = CorrVAL[0];
		}
		else { corrCoeffAt0 = 1; }
		for (iLag = 0; iLag < numLAGs; iLag++)
		{
			CorrVAL[iLag] = CorrVAL[iLag]/corrCoeffAt0;
		}
	}
	//display data in Tables
	if (isOpen("CorrelationCoefficients")==true) { close("CorrelationCoefficients"); }
	Array.show("CorrelationCoefficients", LagVALs, CorrVAL);
	selectWindow("CorrelationCoefficients");
	Table.setLocationAndSize(0, 0, 250, 250);
}


//function to find the secondary peak (1st peak after lag 0) in ACF curves, which indicates periodicity
//input is a 1D array of ACF, its corresponding lag value array, and the number of adjacent points for averaging, so that noisy small peaks are avoided
function getACFperiodicity(ACFcoefVal, ACFlagVals, avgPOINTS) //ouput is an array, first element is the periodicity, which is the lag location of the secondary peak, second element is the peak prominence
{
	lACF = lengthOf(ACFcoefVal);
	
	sPeakLAG = -1;
	sPeakVAL = -1;
	firstDIPval = -1;
	firstDIPfound = false;
	//Loop through the ACF values starting after Lag 0
	for (iLag = 1; iLag < lACF; iLag++)
	{
		//average the values on the left (NEGative) side of a point on the ACF
		avgNEG = 0;
		countPOINTS = 0;
		for (iSmooth=(iLag-avgPOINTS); iSmooth <= iLag; iSmooth++)
		{
			if (iSmooth>0)
			{
				avgNEG = avgNEG + ACFcoefVal[iSmooth];
				countPOINTS=countPOINTS+1;
			}
		}
		avgNEG = avgNEG/countPOINTS;
		//average the values on the right (POSitive) side of a point on the ACF
		avgPOS = 0;
		countPOINTS = 0;
		for (iSmooth=iLag; iSmooth <= (iLag+avgPOINTS); iSmooth++)
		{
			if (iSmooth<lACF)
			{
				avgPOS = avgPOS + ACFcoefVal[iSmooth];
				countPOINTS=countPOINTS+1;
			}
		}
		avgPOS = avgPOS/countPOINTS;
		//Check if the first dip (local minimum) is found
		if (firstDIPfound==false)
		{
			if ((ACFcoefVal[iLag]<=avgNEG)&&(ACFcoefVal[iLag]<=avgPOS))
			{
				firstDIPfound = true;
				firstDIPval = ACFcoefVal[iLag];
			}
		}
		else //Once past the first dip, find the next local maximum (the first peak)
		{
			if ((ACFcoefVal[iLag]>=avgNEG)&&(ACFcoefVal[iLag]>=avgPOS))
			{
				sPeakLAG = ACFlagVals[iLag]; //gives periodicity
				sPeakVAL = ACFcoefVal[iLag]-firstDIPval; //gives peak prominence
				break; //Exit loop once the first peak after the first dip is found
			}
		}
	}
	return newArray(sPeakLAG,sPeakVAL);
}


//function to perform 1D Fast Hartley Transform using ImageJ's function- Array.fourier(FHTinput, FHTwindowTYPE)
//does additional 0-padding to the input signal before performing FHT for proper windowing, and also generates a frequency array
function getFHT(INPUTarray,FHTwindowTYPE) //the function gives 2 arrays as output: FHTfreq and FHTrmsAMP in a Table called "FFTvals"
{
	//find the next-nearest power of 2 for the input array length
	lenInput = lengthOf(INPUTarray);
	iPow = 0;
	nnPow2 = 0;
	while (pow(2, iPow)<lenInput)
	{
		iPow = iPow+1;
		nnPow2 = iPow;
	}
	lenInputNEW = pow(2, nnPow2);
	
	//pad the input array with 0's to a size next-nearest power of 2
	FHTinput = newArray(lenInputNEW);
	Array.fill(FHTinput, 0);
	iPadBEGIN = floor((lenInputNEW-lenInput)/2);
	iPadEND = iPadBEGIN+lenInput;
	iOriginal = 0;
	for (iPad = 0; iPad < lenInputNEW; iPad++)
	{
		if ((iPad>=iPadBEGIN)&&(iPad<iPadEND))
		{
			FHTinput[iPad] = INPUTarray[iOriginal];
			iOriginal = iOriginal + 1;
		}
	}
	
	//Apply 1D Fast Hartley Transform on the padded array
	FHTrmsAMP = Array.fourier(FHTinput, FHTwindowTYPE);
	
	//Generate frequency array
	lenFHT = lengthOf(FHTrmsAMP);
	FHTfreq = newArray(lenFHT);
	for (iPer = 0; iPer < lenFHT; iPer++)
	{
		FHTfreq[iPer] = iPer/(2*lenFHT);
	}
	//display data in Tables
	if (isOpen("FFTvals")==true) { close("FFTvals"); }
	Array.show("FFTvals", FHTfreq, FHTrmsAMP);
	selectWindow("FFTvals");
	Table.setLocationAndSize(0, 0, 250, 250);
}