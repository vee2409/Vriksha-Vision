dataFolder = fullfile(tempdir,"forestData",filesep);
dataFile = dataFolder + "forestData.laz";   
% Check whether the folder and data file already exist or not
folderExists = exist(dataFolder,'dir');
fileExists = exist(dataFile,'file');
% Create a new folder if it doesn't exist
if ~folderExists
    mkdir(dataFolder);
end
% Extract aerial data file if it doesn't exist
if ~fileExists
    unzip('forestData.zip',dataFolder);
end
% Read LAZ data from file
lasReader = lasFileReader(dataFile);
% Read point cloud along with corresponding scan angle information
[ptCloud,pointAttributes] = readPointCloud(lasReader,"Attributes","ScanAngle");
% Visualize the input point cloud
figure
pcshow(ptCloud.Location)
title("Input Point Cloud")

% Segment Ground and extract non-ground and ground points
groundPtsIdx = segmentGroundSMRF(ptCloud);
nonGroundPtCloud = select(ptCloud,~groundPtsIdx);
groundPtCloud = select(ptCloud,groundPtsIdx);
% Visualize non-ground and ground points in magenta and green, respectively
figure
pcshowpair(nonGroundPtCloud,groundPtCloud)
title("Segmented Non-Ground and Ground Points")

groundPoints = groundPtCloud.Location;
% Eliminate duplicate points along x- and y-axes
[uniqueZ,uniqueXY] = groupsummary(groundPoints(:,3),groundPoints(:,1:2),@mean);
uniqueXY = [uniqueXY{:}];
% Create interpolant and use it to estimate ground elevation at each point
F = scatteredInterpolant(double(uniqueXY),double(uniqueZ),"natural");
estElevation = F(double(ptCloud.Location(:,1)),double(ptCloud.Location(:,2)));
% Normalize elevation by ground
normalizedPoints = ptCloud.Location;
normalizedPoints(:,3) = normalizedPoints(:,3) - estElevation;
% Visualize normalized points
figure
pcshow(normalizedPoints)
title("Point Cloud with Normalized Elevation")

% Set grid size to 10 meters per pixel and cutOffHeight to 2 meters
gridSize = 10;
cutOffHeight = 2;
leafAngDistribution = 0.5;
% Extract forest metrics
[canopyCover,gapFraction,leafAreaIndex] = helperExtractForestMetrics(normalizedPoints, ...
    pointAttributes.ScanAngle,gridSize,cutOffHeight,leafAngDistribution);
% Visualize forest metrics
hForestMetrics = figure;
axCC = subplot(2,2,1,Parent=hForestMetrics);
axCC.Position = [0.05 0.51 0.4 0.4];
imagesc(canopyCover,Parent=axCC)
title(axCC,"Canopy Cover")
axis off
colormap(gray)
axGF = subplot(2,2,2,Parent=hForestMetrics);
axGF.Position = [0.55 0.51 0.4 0.4];
imagesc(gapFraction,'Parent',axGF)
title(axGF,"Gap Fraction")
axis off
colormap(gray)
axLAI = subplot(2,2,[3 4],Parent=hForestMetrics);
axLAI.Position = [0.3 0.02 0.4 0.4];
imagesc(leafAreaIndex,Parent=axLAI)
title(axLAI,"Leaf Area Index")
axis off
colormap(gray)

% Set grid size to 0.5 meters per pixel 
gridRes = 0.5;
% Generate CHM
canopyModel = pc2dem(pointCloud(normalizedPoints),gridRes,CornerFillMethod="max");
% Clip invalid and negative CHM values to zero
canopyModel(isnan(canopyModel) | canopyModel<0) = 0;
% Perform gaussian smoothing to remove noise effects
H = fspecial("gaussian",[5 5],1);
canopyModel = imfilter(canopyModel,H,'replicate','same');
% Visualize CHM
figure
imagesc(canopyModel)
title('Canopy Height Model')
axis off
colormap(gray)

% Set minTreeHeight to 5 m 
minTreeHeight = 5;
% Detect tree tops
[treeTopRowId,treeTopColId] = helperDetectTreeTops(canopyModel,gridRes,minTreeHeight);
% Visualize treetops
figure
imagesc(canopyModel)
hold on
plot(treeTopColId,treeTopRowId,"rx",MarkerSize=3)
title("CHM with Detected Tree Tops")
axis off
colormap("gray")

% Segment individual trees
label2D = helperSegmentTrees(canopyModel,treeTopRowId,treeTopColId,minTreeHeight);
% Identify row and column id of each point in label2D and transfer labels
% to each point
rowId = ceil((ptCloud.Location(:,2) - ptCloud.YLimits(1))/gridRes) + 1;
colId = ceil((ptCloud.Location(:,1) - ptCloud.XLimits(1))/gridRes) + 1;
ind = sub2ind(size(label2D),rowId,colId);
label3D = label2D(ind);
% Extract valid labels and corresponding points
validSegIds = label3D ~= 0;
ptVeg = select(ptCloud,validSegIds);
veglabel3D = label3D(validSegIds);
% Assign color to each label
numColors = max(veglabel3D);
colorMap = randi([0 255],numColors,3)/255;
labelColors = label2rgb(veglabel3D,colorMap,OutputFormat="triplets");
% Visualize tree segments
figure
pcshow(ptVeg.Location,labelColors)
title("Individual Tree Segments")
view(2)