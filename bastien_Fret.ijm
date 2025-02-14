////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////// This macro was written in february 2021 by Alexandre Hego 
////// This macro will measure the FRET ratio but we need to calculate first the coefficient
////// This macro will run in batch mode and need bio-format
////// If you need more informations please contact alexandre.hego@uliege.be
////// Please remove the space in the folder name and file name
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// For exemple with Bastien Moes staining mb
// IDD mesure 998
// IDAb mesure 1130
// IDA mesure 1354
// IAA mesure 3013



#@ File (label = "Input directory", style = "directory") input
#@ Integer (label = "Donor alone (Green) mean exGreen-emGreen", min=0, max= 65535, value = 998) IDD
#@ Integer (label = "Donor alone (Green) mean exGreen-emRed", min=0, max= 65535, value = 1130) IDAb
#@ Integer (label = "Acceptor alone (Red) mean exGreen-emRed", min=0, max= 65535, value = 1354) IDA
#@ Integer (label = "Acceptor alone (Red) mean exRed-emRed", min=0, max= 65535, value = 3013) IAA
#@ String (label = "File suffix", value = ".czi") suffix

output= input + "/image_jpeg/";
output2= input + "/image_tif/";
output3 =  input + "/statistics/";
File.makeDirectory(output);
File.makeDirectory(output2);
File.makeDirectory(output3);


Coef_B = IDAb / IDD;
Coef_D = IDA / IAA ;

processFolder(input);

// function to scan folders/subfolders/files to find files with correct suffix
function processFolder(input) {
	list = getFileList(input);
	list = Array.sort(list);
	for (i = 0; i < list.length; i++) {
		if(File.isDirectory(input + File.separator + list[i]))
			processFolder(input + File.separator + list[i]);
		if(endsWith(list[i], suffix))
			processFile(input, output, list[i]);
	}
}

function processFile(input, output, file) {
inputPath = input + File.separator + list[i];
run("Bio-Formats Importer", "open=inputPath color_mode=Default rois_import=[ROI manager] view=Hyperstack stack_order=XYCZT");
imagesName = getTitle();
rename("mask");
run("Split Channels");


//Creation cell mask base on DAPI
////////////////////////////////////////////////
selectImage("C4-" + "mask");
rename("nuclei");
run("Gaussian Blur...", "sigma=3");
setAutoThreshold("Huang dark");
setOption("BlackBackground", true);
run("Convert to Mask");
run("Dilate");
run("Dilate");
run("Fill Holes");
run("Watershed");
run("Analyze Particles...", "size=26-Infinity show=Masks exclude");
selectImage("nuclei");
close();
selectImage("Mask of nuclei");
rename("nuclei");
run("Invert LUT");
run("Analyze Particles...", "clear add");
/////////////////////////////////////////////////


/* Stratégie de mesure 
 *  calcule Fret corr = Ia (ex donor em acceptor = yellow) - Coef_B * ID (ex donor em donor = green) - Coef_D * IAb (ex accptor em acceptor = red)
 *  Fret_corr = Ia - Coef_B*ID - CoefD*IAb
 *  Fret_corr = Ia - (Coef_B*ID + Coef_D*IAb)
 *  
 *  //ID * coef B
 *  etape 1 select image green and run("Multiply...", "value="+ Coef_B); 
 *  // IAb * Coef_D
 *  etape 2 select image red and run("Multiply...", "value="+ Coef_D); 
 *  // ID * coef B + IAb * Coef_D
 *  imageCalculator("Add create", "Untitled","Untitled-1");
 *  // Ia - (Coef_B*ID + Coef_D*IAb)
 *  imageCalculator("Subtract create", "Untitled","Untitled-1");
 *  
 *  Fret_ratio = Fret_corr /ID (green)
 */

//etape 1 select image green and run("Multiply...", "value="+ Coef_B); 
//////////////////////////////////////////////////////////////
selectImage("C3-" + "mask");
rename("green");
run("Duplicate...", "title=green_bis");
selectImage("green_bis");
run("Multiply...", "value="+ Coef_B); 

//etape 2 select image red and run("Multiply...", "value="+ Coef_D); 
//////////////////////////////////////////////////////////////
selectImage("C1-" + "mask");
rename("red");
run("Multiply...", "value="+ Coef_D); 

// etape 3     ID * coef B + IAb * Coef_D
///////////////////////////////////////////////////////////////
imageCalculator("Add create", "red","green_bis");
selectWindow("green_bis");
close();
selectWindow("red");
close();
selectWindow("Result of red");
rename("red");

// etape 4    Ia - (Coef_B*ID + Coef_D*IAb)
//////////////////////////////////////////////////////////////
selectImage("C2-" + "mask");
rename("yellow");
imageCalculator("Subtract create", "yellow","red");
selectImage("yellow");
close();
selectImage("Result of yellow");
rename("yellow");

// etape 5 Fret_ratio = Fret_corr /ID (green)
imageCalculator("Divide create 32-bit", "yellow","green");
////////////////////////////////////////////////////////////////////

//Measurements
////////////////////////////////////////////////////////////////////
run("Set Measurements...", "area mean min median redirect=None decimal=3");
selectWindow("Result of yellow");
roiManager("Show All");
roiManager("Measure");
selectWindow("Results"); 
selectImage("nuclei");
saveAs("Tiff", output2 + File.separator  +imagesName +"_cells_mask" );
saveAs("Measurements", output3 +  imagesName + "_measurements.csv");

/////////////////////////////////////////////////////////////////

// Save image for quality control
///////////////////////////////////////////////////////////////////
selectWindow("Result of yellow");
roiManager("Show None");
saveAs("Tiff", output2 + File.separator  +imagesName +"_ratio" );
run("Rainbow RGB");
setMinAndMax(0, 2);
run("Calibration Bar...", "location=[Upper Right] fill=White label=Black number=3 decimal=1 font=10 zoom=3 bold overlay");
saveAs("JPG", output + File.separator  +imagesName +"_ratio" );
run("Clear Results");
close("*");
run("Close All");
}

