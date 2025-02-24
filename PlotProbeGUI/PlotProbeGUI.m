function varargout = PlotProbeGUI(varargin)
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @PlotProbeGUI_OpeningFcn, ...
                   'gui_OutputFcn',  @PlotProbeGUI_OutputFcn, ...
                   'gui_LayoutFcn',  [] , ...
                   'gui_Callback',   []);
if nargin && ischar(varargin{1}) && ~strcmp(varargin{end},'userargs')
    if varargin{1}(1)=='.'
        varargin{1}(1) = '';
    end
    gui_State.gui_Callback = str2func(varargin{1});
end

if nargout
    [varargout{1:nargout}] = gui_mainfcn(gui_State, varargin{:});
else
    gui_mainfcn(gui_State, varargin{:});
end



% -------------------------------------------------------------
function varargout = PlotProbeGUI_OutputFcn(hObject, eventdata, handles)
handles.updateptr = @PlotProbeGUI_Update;
handles.closeptr = @PlotProbeGUI_Close;
varargout{1} = handles;



% ----------------------------------------------------------------------
function Initialize(handles)
global plotprobe

plotprobe = [];

plotprobe.status = -1;

% These are the parameters that are assigned from external sources,
% either from GUI arguments or parent GUI. 
plotprobe.format = '';
plotprobe.datatype = [];
plotprobe.condition = [];
plotprobe.pos = [];

% Rest of the parameters 
plotprobe.datatypeVals = struct('RAW',1, 'RAW_HRF',2, 'OD',4, 'OD_HRF',8, 'CONC',16, 'CONC_HRF',32);
plotprobe.name = 'plotprobe';
plotprobe.y = {};
plotprobe.t = {};
plotprobe.handles.data = [];
plotprobe.handles.figureDup = [];
SetGuiControls(handles)

if ispc()
    setGuiFonts(hObject);
else
    setGuiFonts(hObject, 7);
end


% ----------------------------------------------------------------------
function SetGuiControls(handles)
global plotprobe

plotprobe.axScl       = str2num(get(handles.editPlotProbeAxScl, 'string'));
plotprobe.tMarkInt    = str2num(get(handles.editPlotProbeTimeMarkersInt, 'string'));
plotprobe.tMarkAmp    = str2num(get(handles.editPlotProbeTimeMarkersAmp, 'string'));
plotprobe.tMarkShow   = get(handles.radiobuttonShowTimeMarkers, 'value');
plotprobe.tMarkUnits  = str2num(get(handles.textTimeMarkersAmpUnits, 'string'));
plotprobe.hidMeasShow = get(handles.radiobuttonShowHiddenMeas, 'value');
 


% ----------------------------------------------------------------------
function ParseArgs(args)
global plotprobe
global maingui

if ~exist('args','var')
    return;
end

varargin = args;

%%%% These are the parameters that are assigned from external soutrces,
%%%% either from GUI arguments or parent GUI. 
%
% plotprobe.format
% plotprobe.datatype
% plotprobe.condition
% plotprobe.pos
%

%  Syntax:
%
%     PlotProbeGUI()
%     PlotProbeGUI(format)
%     PlotProbeGUI(format, pos)
%     PlotProbeGUI(format, datatype)
%     PlotProbeGUI(format, datatype, pos)
%     PlotProbeGUI(format, datatype, condition)
%     PlotProbeGUI(format, datatype, condition, pos)
%     PlotProbeGUI(datatype)
%     PlotProbeGUI(datatype, pos)
%     PlotProbeGUI(datatype, condition)
%     PlotProbeGUI(datatype, condition, pos)

% Arguments take precedence over parent gui parameters
if length(varargin)==0
    return;                                                  % PlotProbeGUI()
elseif length(varargin)==1
    if ischar(varargin{1})                 
        plotprobe.format = varargin{1};                      % PlotProbeGUI(format)
    elseif iswholenum(varargin{1}) & length(varargin{1})==1
        plotprobe.datatype = varargin{1};                    % PlotProbeGUI(datatype)
    end
elseif length(varargin)==2
    if ischar(varargin{1})
        plotprobe.format = varargin{1};
        if isreal(varargin{2}) & length(varargin{2})==4     
            plotprobe.pos = varargin{2};                    % PlotProbeGUI(format, pos)
        elseif iswholenum(varargin{2}) & length(varargin{2})==1
            plotprobe.datatype = varargin{2};               % PlotProbeGUI(format, datatype)
        end
    elseif isreal(varargin{2}) & length(varargin{2})==4
        plotprobe.datatype = varargin{1};                   % PlotProbeGUI(datatype, pos)
        plotprobe.pos = varargin{2};
    elseif iswholenum(varargin{2}) & length(varargin{2})==1
        plotprobe.datatype = varargin{1};                   % PlotProbeGUI(datatype, condition)
        plotprobe.condition = varargin{2};
    end
elseif length(varargin)==3
    if ischar(varargin{1})
        plotprobe.format = varargin{1};
        if isreal(varargin{3}) & length(varargin{3})==4
            plotprobe.datatype = varargin{2};
            plotprobe.pos = varargin{3};                    % PlotProbeGUI(format, datatype, pos)
        elseif iswholenum(varargin{3}) & length(varargin{3})==1
            plotprobe.datatype = varargin{2};               
            plotprobe.condition = varargin{3};              % PlotProbeGUI(format, datatype, condition)
        end
    elseif iswholenum(varargin{1})
        plotprobe.datatype = varargin{1};
        plotprobe.condition = varargin{2};                  % PlotProbeGUI(datatype, condition, pos)
        plotprobe.pos = varargin{3};
    end
elseif length(varargin)==4
    plotprobe.format    = varargin{1};
    plotprobe.datatype  = varargin{2};
    plotprobe.condition = varargin{3};
    plotprobe.pos       = varargin{4};                      % PlotProbeGUI(format, datatype, condition, pos)
end

% Now whichever of the above parameters weren't assigned values
% obtain values either from parent gui or assign default value
if isempty(maingui)
    if isempty(plotprobe.format)
        plotprobe.format = 'snirf';
    end
    if isempty(plotprobe.datatype)
        plotprobe.datatype = plotprobe.datatypeVals.CONC_HRF;
    end
    if isempty(plotprobe.condition)
        plotprobe.condition = 1;
    end
else
    if isempty(plotprobe.format)
        plotprobe.format = maingui.format;
    end
    if isempty(plotprobe.datatype)
        plotprobe.datatype = maingui.guiControls.datatype;
    end
    if isempty(plotprobe.condition)
        plotprobe.condition = maingui.guiControls.condition;
    end
end



% ----------------------------------------------------------------------
function PlotProbeGUI_OpeningFcn(hObject, eventdata, handles, varargin)
%
%  Syntax:
%
%     PlotProbeGUI()
%     PlotProbeGUI(format)
%     PlotProbeGUI(format, pos)
%     PlotProbeGUI(format, datatype, pos)
%     PlotProbeGUI(format, datatype, condition)
%     PlotProbeGUI(format, datatype, condition, pos)
%     PlotProbeGUI(datatype, pos)
%     PlotProbeGUI(datatype, condition)
%     PlotProbeGUI(datatype, condition, pos)
%  
%  Description:
%     GUI for displaying HRF plots for all probe channels. 
%     
%     NOTE: This GUIs input parameters are passed to it either as formal arguments 
%     or through the calling parent GUIs generic global variable, 'maingui'. If it's 
%     the latter, this GUI follows the rule that it accesses the parent GUIs global 
% 	  variable ONLY at startup time, that is, in the function <GUI Name>_OpeningFcn(). 
%
%  Input:
%     format:    Which acquisition type of files to load to dataTree: e.g., nirs, snirf, etc
%     pos:       Size and position of last figure session
%     datatype:  Takes 2 integer values {8 = OD HRF, 32 = concentration HRF}. Any other values will be ignored and nothing will be pl 
%     condition: Integer index telling which condition 
%

global plotprobe
global maingui

% Choose default command line output for PlotProbeGUI
handles.output = hObject;
guidata(hObject, handles);

Initialize(handles);

% Parse GUI args
ParseArgs(varargin);

% See if we can recover previous position
p = plotprobe.pos;
if ~isempty(p)
    set(hObject, 'position', [p(1), p(2), p(3), p(4)]);
end
plotprobe.version  = get(hObject, 'name');
plotprobe.dataTree = LoadDataTree(plotprobe.format, '', maingui);
if plotprobe.dataTree.IsEmpty()
    return;
end

if length(plotprobe.y)>1
    msg{1} = sprintf('Warning: Data in this plot probe uses different Y scales for different data blocks ');
    msg{2} = sprintf('for which a single scale has not yet been implemented. A single scale for mutiple data blocks ');
    msg{3} = sprintf('will be implemented in a future release. Note that single block data sets are ');
    msg{4} = sprintf('unaffected by this issue; i.e., all data from all channels are plotted using the same scale.');
    MessageBox([msg{:}], 'Feature Not Yet Fully Implemented');
    return;
end
 
% If parent gui exists disable these menu options which only make sense when 
% running this GUI standalone
if ~isempty(maingui)
    set(handles.menuFile,'visible','off');
    set(handles.menuItemChangeGroup,'visible','off');
    set(handles.menuItemSaveGroup,'visible','off');
    plotprobe.updateParentGui = maingui.Update;
end
DisplayData(handles, hObject);



% ----------------------------------------------------------------------
function DisplayData(handles, hObject)
global plotprobe

% Some callbacks which call DisplayData serve double duty as called functions 
% from other callbacks which in turn call DisplayData. To avoid double or
% triple redisplaying in a single thread, exit DisplayData if hObject is
% not a handle. 
if ~exist('hObject','var')
    hObject=[];
end
if ~ishandles(hObject)
    return;
end

axes(handles.axes1);
set(handles.axes1, 'xlim', [0,1], 'ylim', [0,1]);

% Clear axes
cla(handles.axes1); 
axis off;

condition = plotprobe.condition;
datatype  = plotprobe.datatype;
currElem  = plotprobe.dataTree.currElem;

% Clear axes of previous data, before redisplaying it
ClearAxesData();

hold on
nDataBlks = plotprobe.dataTree.currElem.GetDataBlocksNum();
plotprobe.y = cell(nDataBlks,1);
plotprobe.t = cell(nDataBlks,1);
for iBlk=1:nDataBlks
    if datatype == plotprobe.datatypeVals.OD_HRF
        plotprobe.y{iBlk} = currElem.GetDodAvg(condition, iBlk);
        plotprobe.t{iBlk} = currElem.GetTHRF();
        plotprobe.tMarkUnits='(AU)';
    elseif datatype == plotprobe.datatypeVals.CONC_HRF
        plotprobe.y{iBlk} = currElem.GetDcAvg(condition, iBlk);
        plotprobe.t{iBlk} = currElem.GetTHRF();
        plotprobe.tMarkAmp = plotprobe.tMarkAmp/1e6;
        plotprobe.tMarkUnits = '(micro-molars)';
    end
    plotProbeAndSetProperties(handles, iBlk);
end
hold off



% ----------------------------------------------------------------------
function editPlotProbeAxScl_Callback(hObject, eventdata, handles)
global plotprobe

foo = str2num( get(hObject,'string') );
if length(foo)<2
    foo = plotprobe.axScl;
elseif foo(1)<=0 | foo(2)<=0
    foo = plotprobe.axScl;
end    
plotprobe.axScl = foo;

% Clear axes of previous data, before redisplaying it
ClearAxesData();

set(hObject,'string', sprintf('%0.1f %0.1f', plotprobe.axScl) );
nDataBlks = plotprobe.dataTree.currElem.GetDataBlocksNum();
for iBlk=1:nDataBlks
    plotProbeAndSetProperties(handles, iBlk);
end



% ----------------------------------------------------------------------
function pushbuttonPlotProbeYdec_Callback(hObject, eventdata, handles)
global plotprobe 

hEditScl = handles.editPlotProbeAxScl;

plotprobe.axScl(2) = plotprobe.axScl(2) - 0.1;
set(hEditScl,'string', sprintf('%0.1f %0.1f', plotprobe.axScl) );

% Clear axes of previous data, before redisplaying it
ClearAxesData();

nDataBlks = plotprobe.dataTree.currElem.GetDataBlocksNum();
for iBlk=1:nDataBlks
    plotProbeAndSetProperties(handles, iBlk);
end



% ----------------------------------------------------------------------
function pushbuttonPlotProbeYinc_Callback(hObject, eventdata, handles)
global plotprobe 

hEditScl = handles.editPlotProbeAxScl;

plotprobe.axScl(2) = plotprobe.axScl(2) + 0.1;
set(hEditScl,'string', sprintf('%0.1f %0.1f', plotprobe.axScl) );

% Clear axes of previous data, before redisplaying it
ClearAxesData();

nDataBlks = plotprobe.dataTree.currElem.GetDataBlocksNum();
for iBlk=1:nDataBlks
    plotProbeAndSetProperties(handles, iBlk);
end



% ----------------------------------------------------------------------
function pushbuttonPlotProbeXdec_Callback(hObject, eventdata, handles)
global plotprobe 
hEditScl = handles.editPlotProbeAxScl;

plotprobe.axScl(1) = plotprobe.axScl(1) - 0.1;
set(hEditScl,'string', sprintf('%0.1f %0.1f', plotprobe.axScl) );

% Clear axes of previous data, before redisplaying it
ClearAxesData();

nDataBlks = plotprobe.dataTree.currElem.GetDataBlocksNum();
for iBlk=1:nDataBlks
    plotProbeAndSetProperties(handles, iBlk);
end



% ----------------------------------------------------------------------
function pushbuttonPlotProbeXinc_Callback(hObject, eventdata, handles)
global plotprobe 

hEditScl = handles.editPlotProbeAxScl;

plotprobe.axScl(1) = plotprobe.axScl(1) + 0.1;
set(hEditScl,'string', sprintf('%0.1f %0.1f', plotprobe.axScl) );
nDataBlks = plotprobe.dataTree.currElem.GetDataBlocksNum();

% Clear axes of previous data, before redisplaying it
ClearAxesData();

for iBlk=1:nDataBlks
    plotProbeAndSetProperties(handles, iBlk);
end



% ----------------------------------------------------------------------
function radiobuttonShowTimeMarkers_Callback(hObject, evendata, handles)
global plotprobe

plotprobe.tMarkShow = get(hObject,'value');
if plotprobe.tMarkShow
    set(plotprobe.handles.data(:,4:end), 'visible','on');
else
    set(plotprobe.handles.data(:,4:end), 'visible','off');    
end



% ----------------------------------------------------------------------
function editPlotProbeTimeMarkersAmp_Callback(hObject, eventdata, handles)
global plotprobe

datatype     = plotprobe.datatype;
datatypeVals = plotprobe.datatypeVals;

plotprobe.tMarkAmp = str2num(get(hObject,'string'));
if datatype == datatypeVals.CONC_HRF
    plotprobe.tMarkAmp = plotprobe.tMarkAmp/1e6;
end

% Clear axes of previous data, before redisplaying it
ClearAxesData();

nDataBlks = plotprobe.dataTree.currElem.GetDataBlocksNum();
for iBlk=1:nDataBlks
    plotProbeAndSetProperties(handles, iBlk);
end


% ----------------------------------------------------------------------
function editPlotProbeTimeMarkersInt_Callback(hObject, eventdata, handles)
global plotprobe

t  = plotprobe.dataTree.currElem.GetTHRF();

foo = str2num( get(hObject,'string') );
if length(foo)~=1
    foo = plotprobe.tMarkInt;
elseif ~isnumeric(foo)
    foo = plotprobe.tMarkInt;
elseif foo<5 || foo>t(end)
    foo = plotprobe.tMarkInt;
end
plotprobe.tMarkInt = foo;
set(hObject,'string', sprintf('%0.1f ',plotprobe.tMarkInt) );

% Clear axes of previous data, before redisplaying it
ClearAxesData();

nDataBlks = plotprobe.dataTree.currElem.GetDataBlocksNum();
for iBlk=1:nDataBlks
    plotProbeAndSetProperties(handles, iBlk);
end



% ----------------------------------------------------------------------
function pushbuttonPlotProbeDuplicate_Callback(hObject, eventdata, handles)
global plotprobe

if ishandles(plotprobe.handles.figureDup)
    delete(plotprobe.handles.figureDup);
end

%%%% Get the zoom level of the original plotProbe axes
figure(handles.figure);
a = get(gca,'xlim');
b = get(gca,'ylim');

%%%% Create new figure and use same zoom level and axes position 
%%%% as original 
plotprobe.handles.figureDup = figure();
xlim(a);
ylim(b);
pos = getNewFigPos(plotprobe.handles.figureDup);
set(plotprobe.handles.figureDup, 'position',pos);

nDataBlks = plotprobe.dataTree.currElem.GetDataBlocksNum();
for iBlk=1:nDataBlks
    plotProbeAndSetProperties(handles, iBlk);
end



% ---------------------------------------------
function pos = getNewFigPos(hFig)

p = get(hFig,'position');

% Find upper right corner of figure
pu = [p(1)+p(3), p(2)+p(4)];

% find center position of figure
c = [p(1)+(pu(1)-p(1))/2, p(2)+(pu(2)-p(2))/2];

% determine which direction to move new figure relative 
% to hFig based on which quadrant of the screen the center
% of hFig appears.
scrsz = get(0,'screensize');
if c(1)>scrsz(3)/2
    q=-1;
else
    q=+1;
end
if c(2)>scrsz(4)/2
    r=-1;
else
    r=+1;
end
offsetX = q*scrsz(3)*.1;
offsetY = r*scrsz(4)*.1;

pos = [p(1)+offsetX p(2)+offsetY p(3) p(4)];



% ----------------------------------------------------------------------
function radiobuttonShowHiddenMeas_Callback(hObject, eventdata, handles)
global plotprobe
plotprobe.hidMeasShow = get(hObject,'value');
nDataBlks = plotprobe.dataTree.currElem.GetDataBlocksNum();
for iBlk=1:nDataBlks    
    showHiddenObjs(iBlk);
end



% ----------------------------------------------------------------------
function PlotProbeGUI_Close(hObject, eventdata, handles)
global plotprobe
plotprobe.updateParentGui('PlotProbeGUI');
if ishandles(plotprobe.handles.figureDup)
    delete(plotprobe.handles.figureDup);
end




% ----------------------------------------------------------------------
function PlotProbeGUI_Update(handles, varargin)
global plotprobe

if isempty(plotprobe)
    return
end

ParseArgs(varargin);
axes(handles.axes1);

condition = plotprobe.condition;
datatype  = plotprobe.datatype;

% Clear axes of previous data, before redisplaying it
ClearAxesData();

nDataBlks = plotprobe.dataTree.currElem.GetDataBlocksNum();
plotprobe.y = cell(nDataBlks,1);
plotprobe.t = cell(nDataBlks,1);
for iBlk=1:nDataBlks
    if datatype == plotprobe.datatypeVals.OD_HRF
        plotprobe.y{iBlk} = plotprobe.dataTree.currElem.GetDodAvg(condition, iBlk);
        plotprobe.t{iBlk} = plotprobe.dataTree.currElem.GetTHRF();
        plotprobe.tMarkUnits='(AU)';
    elseif datatype == plotprobe.datatypeVals.CONC_HRF
        plotprobe.y{iBlk} = plotprobe.dataTree.currElem.GetDcAvg(condition, iBlk);
        plotprobe.t{iBlk} = plotprobe.dataTree.currElem.GetTHRF();
        plotprobe.tMarkAmp = plotprobe.tMarkAmp/1e6;
        plotprobe.tMarkUnits = '(micro-molars)';
    end
    plotProbeAndSetProperties(handles, iBlk);
end


% ----------------------------------------------------------------------
function ClearAxesData()
global plotprobe
if ishandles(plotprobe.handles.data)
    delete(plotprobe.handles.data);
    plotprobe.handles.data = [];
end



% --------------------------------------------------------------------
function menuItemChangeGroup_Callback(hObject, eventdata, handles)
pathname = uigetdir(pwd, 'Select a NIRS data group folder');
if pathname==0
    return;
end
cd(pathname);
PlotProbeGUI();



% --------------------------------------------------------------------
function pushbuttonExit_Callback(hObject, eventdata, handles)
if ishandles(handles.figure)
    delete(handles.figure);
end


