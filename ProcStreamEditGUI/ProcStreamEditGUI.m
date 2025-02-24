function varargout = ProcStreamEditGUI(varargin)
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @ProcStreamEditGUI_OpeningFcn, ...
                   'gui_OutputFcn',  @ProcStreamEditGUI_OutputFcn, ...
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
function varargout = ProcStreamEditGUI_OutputFcn(hObject, eventdata, handles)
handles.updateptr = @ProcStreamEditGUI_Update;
handles.closeptr = [];
varargout{1} = handles;


% -------------------------------------------------------------
function ProcStreamEditGUI_OpeningFcn(hObject, eventdata, handles, varargin)
%
%  Syntax:
%
%     ProcStreamEditGUI()
%     ProcStreamEditGUI(format)
%     ProcStreamEditGUI(format, pos)
%  
%  Description:
%     GUI used for editing the processing stream chain of function calls. 
%     
%     NOTE: This GUIs input parameters are passed to it either as formal arguments 
%     or through the calling parent GUIs generic global variable, 'maingui'. If it's 
%     the latter, this GUI follows the rule that it accesses the parent GUIs global 
% 	  variable ONLY at startup time, that is, in the function <GUI Name>_OpeningFcn(). 
%
%  Inputs:
%     format:    Which acquisition type of files to load to dataTree: e.g., nirs, snirf, etc
%     pos:       Size and position of last figure session
%
global procStreamEdit
global maingui

% Choose default command line output for ProcStreamEditGUI
handles.output = hObject;
guidata(hObject, handles);

procStreamEdit = [];

%%%% Begin parse arguments 

procStreamEdit.format = '';
procStreamEdit.pos = [];
procStreamEdit.updateParentGui = [];
if ~isempty(maingui)
    procStreamEdit.format = maingui.format;
    procStreamEdit.updateParentGui = maingui.Update;

    % If parent gui exists disable these menu options which only make sense when 
    % running this GUI standalone
    set(handles.menuItemChangeGroup,'visible','off');
    set(handles.menuItemSaveGroup,'visible','off');
end

% Format argument
if isempty(procStreamEdit.format)
    if isempty(varargin)
        procStreamEdit.format = 'snirf';
    elseif ischar(varargin{1})
        procStreamEdit.format = varargin{1};
    end
end

% Position argument
if isempty(procStreamEdit.pos)
    if length(varargin)==1 && ~ischar(varargin{1})
        procStreamEdit.pos = varargin{1};
    elseif length(varargin)==2 && ~ischar(varargin{2})
        procStreamEdit.pos = varargin{2};
    end
end

%%%% End parse arguments 

% See if we can set the position
p = procStreamEdit.pos;
if ~isempty(p)
    set(hObject, 'position', [p(1), p(2), p(3), p(4)]);
end
procStreamEdit.version = get(hObject, 'name');

procStreamEdit.iRunPanel = 2;
procStreamEdit.iSubjPanel = 3;
procStreamEdit.iGroupPanel = 1;

% Current proc stream listbox strings for the 3 panels
procStreamEdit.listPsUsage = StringsClass().empty();

% Create tabs for run, subject, and group and move the panels to corresponding tabs. 
htabgroup = uitabgroup('parent',hObject, 'units','normalized', 'position',[.04, .04, .95, .95]);
htabR = uitab('parent',htabgroup, 'title','       Run         ', 'ButtonDownFcn',{@uitabRun_ButtonDownFcn, guidata(hObject)});
htabS = uitab('parent',htabgroup, 'title','       Subject         ', 'ButtonDownFcn',{@uitabSubj_ButtonDownFcn, guidata(hObject)});
htabG = uitab('parent',htabgroup, 'title','       Group         ', 'ButtonDownFcn',{@uitabGroup_ButtonDownFcn, guidata(hObject)});

set(handles.uipanelRun, 'parent',htabR, 'position',[0, 0, 1, 1]);
set(handles.uipanelSubj, 'parent',htabS, 'position',[0, 0, 1, 1]);
set(handles.uipanelGroup, 'parent',htabG, 'position',[0, 0, 1, 1]);

setGuiFonts(hObject);

htab = htabR;
procStreamEdit.iPanel = procStreamEdit.iRunPanel;

% Load data tree
procStreamEdit.dataTree = LoadDataTree(procStreamEdit.format, '', maingui);
if ~procStreamEdit.dataTree.IsEmpty()    
    procStreamEdit.procElem{procStreamEdit.iRunPanel} = procStreamEdit.dataTree.group(1).subjs(1).runs(1).copy;
    procStreamEdit.procElem{procStreamEdit.iSubjPanel} = procStreamEdit.dataTree.group(1).subjs(1).copy;
    procStreamEdit.procElem{procStreamEdit.iGroupPanel} = procStreamEdit.dataTree.group(1).copy;
    switch(class(procStreamEdit.dataTree.currElem))
        case 'RunClass'
            htab = htabR;
            procStreamEdit.iPanel = procStreamEdit.iRunPanel;
        case 'SubjClass'
            htab = htabS;
            procStreamEdit.iPanel = procStreamEdit.iSubjPanel;
        case 'GroupClass'
            htab = htabG;
            procStreamEdit.iPanel = procStreamEdit.iGroupPanel;
    end
end

% Select current tab
set(htabgroup,'SelectedTab',htab);

% Load and display registry
LoadRegistry(handles);

% Before we exit display current proc stream by default
LoadProcStream(handles);


% -------------------------------------------------------------
function idx = MapRegIdx(iPanel)
global procStreamEdit

idx = [];
if iPanel==procStreamEdit.iGroupPanel
    idx = procStreamEdit.dataTree.reg.IdxGroup();
elseif iPanel==procStreamEdit.iSubjPanel
    idx = procStreamEdit.dataTree.reg.IdxSubj();    
elseif iPanel==procStreamEdit.iRunPanel
    idx = procStreamEdit.dataTree.reg.IdxRun();
end


% -------------------------------------------------------------
function LoadRegistry(handles)
global procStreamEdit

reg = procStreamEdit.dataTree.reg;
if reg.IsEmpty()
    reg = RegistriesClass();
    if ~isempty(reg.GetSavedRegistryPath())
        fprintf('Loaded saved registry %s\n', reg.GetSavedRegistryPath());
    end
end

for iPanel=1:length(reg.funcReg)
    set(handles.listboxFuncReg(iPanel),'string',reg.funcReg(MapRegIdx(iPanel)).GetFuncNames());
    iFunc = get(handles.listboxFuncReg(iPanel),'value');
    funcname = reg.funcReg(MapRegIdx(iPanel)).GetFuncName(iFunc);
    set(handles.listboxUsageOptions(iPanel),'string',reg.funcReg(MapRegIdx(iPanel)).GetUsageNames(funcname));
    set(handles.listboxUsageOptions(iPanel), 'value',1);
    LookupHelp(iPanel, iFunc, handles);
end



% --------------------------------------------------------------------
function LoadProcStream(handles, reload)
global procStreamEdit

iGroupPanel = procStreamEdit.iGroupPanel;
iSubjPanel  = procStreamEdit.iSubjPanel;
iRunPanel   = procStreamEdit.iRunPanel;
reg         = procStreamEdit.dataTree.reg;

% Create 3 strings objects for run , subject and group: this is
% what will be the current proc stream listbox strings for the 3 panels
if isempty(procStreamEdit.listPsUsage)
    procStreamEdit.listPsUsage(length(procStreamEdit.procElem)) = StringsClass();
end

% If registry is not yet loaded, can't fill in the listboxFuncProcStream
% YET. However it doesn't mean data Tree if not loaded. 
if isempty(reg)
    return;
end

if ~exist('reload','var')
    reload=false;
end
if reload
    procStreamEdit.procElem{iRunPanel} = procStreamEdit.dataTree.group(1).subjs(1).runs(1).copy;
    procStreamEdit.procElem{iSubjPanel} = procStreamEdit.dataTree.group(1).subjs(1).copy;
    procStreamEdit.procElem{iGroupPanel} = procStreamEdit.dataTree.group(1).copy;
end

listPsUsage = procStreamEdit.listPsUsage;
for iPanel=1:length(procStreamEdit.procElem)
    listPsUsage(iPanel).Initialize();
    procStream = procStreamEdit.procElem{iPanel}.procStream;
    for iFcall=1:procStream.GetFuncCallNum()
        fname     = procStream.fcalls(iFcall).GetName();
        fcallname = reg.funcReg(MapRegIdx(iPanel)).GetUsageName(procStream.fcalls(iFcall));
        
        % Line up the procStream entries into 2 columns: func name and func call name, so it's cleares
        listPsUsage(iPanel).Insert(sprintf('%s: %s', fname, fcallname));
    end
    listPsUsage(iPanel).Tabularize();
    set(handles.listboxFuncProcStream(iPanel),'string',listPsUsage(iPanel).Get());
end
procStreamEdit.listPsUsage = listPsUsage;



% -------------------------------------------------------------
function listboxFuncReg_Callback(hObject, eventdata, handles)
global procStreamEdit
iPanel = procStreamEdit.iPanel;
reg    = procStreamEdit.dataTree.reg;

if ~isempty(eventdata) && ~isobject(eventdata)
    set(hObject, 'value',eventdata);
end
    
ii = get(hObject,'value');
if isempty(ii)
    return;
end
funcnames = get(hObject,'string');
if isempty(funcnames)
    return
end
usagenames = reg.funcReg(MapRegIdx(iPanel)).GetUsageNames(funcnames{ii});
iUsage = get(handles.listboxUsageOptions(iPanel), 'value');
if iUsage>length(usagenames)
    iUsage = length(usagenames);
end
set(handles.listboxUsageOptions(iPanel), 'value', iUsage);
set(handles.listboxUsageOptions(iPanel), 'string', usagenames);
LookupHelp(iPanel, ii, handles);



% -------------------------------------------------------------
function listboxFuncProcStream_Callback(hObject, eventdata, handles)
global procStreamEdit
iPanel = procStreamEdit.iPanel;
listPsUsage = procStreamEdit.listPsUsage;

ii = get(hObject,'value');
if isempty(ii)
    return;
end
usagename = listPsUsage(iPanel).GetVal(ii);
if isempty(usagename) || ~ischar(usagename)
    return;
end
LookupHelpFuncCall(iPanel, usagename, handles);



% -------------------------------------------------------------
function listboxUsageOptions_Callback(hObject, eventdata, handles)
global procStreamEdit
iPanel = procStreamEdit.iPanel;

usagenames = get(hObject,'string');
iUsage = get(hObject,'value');
if isempty(iUsage)
    return;
end
iFunc      = get(handles.listboxFuncReg(iPanel),'value');
funcnames  = get(handles.listboxFuncReg(iPanel),'string');
usagename  = sprintf('%s: %s', funcnames{iFunc}, usagenames{iUsage});

LookupHelpFuncCall(iPanel, usagename, handles);



% -------------------------------------------------------------
function pushbuttonAddFunc_Callback(hObject, eventdata, handles)
global procStreamEdit
iPanel = procStreamEdit.iPanel;
listPsUsage = procStreamEdit.listPsUsage;

if isempty(iPanel) || iPanel<1
    return;
end
if isempty(procStreamEdit.dataTree)
    MenuBox('Can''t add functions to processing stream because the data tree is empty',{'OK'})
    return;
end

iFunc      = get(handles.listboxFuncReg(iPanel),'value');
funcnames  = get(handles.listboxFuncReg(iPanel),'string');
iUsage     = get(handles.listboxUsageOptions(iPanel),'value');
usagenames = get(handles.listboxUsageOptions(iPanel),'string');

if isempty(funcnames)
    msg{1} = sprintf('There are no registry functions at this proc level to choose from. ');
    msg{2} = sprintf('Please add functions to registry.');
    MessageBox([msg{:}]);
    return;
end

fcallselect = sprintf('%s: %s', funcnames{iFunc}, usagenames{iUsage});

iFcall = get(handles.listboxFuncProcStream(iPanel),'value');

% fNIRS course exercies suggest that it's ok to have the same function or
% even function call (i.e., usage) in one proc stream, so we comment out next 4 lines.
% to allow this. 
%
% if listPsUsage(iPanel).IsMember(fcallselect, ':')
%     MessageBox('This usage already exist in processing stream. Each usage entry in processing stream must be unique.','OK')
%     return;
% end

iFcall = listPsUsage(iPanel).Insert(fcallselect, iFcall, 'after');
if isempty(iFcall)
    return;
end
listPsUsage(iPanel).Tabularize();
updateProcStreamListbox(handles, iPanel, iFcall);
uicontrol(handles.listboxFuncProcStream(iPanel));



% -------------------------------------------------------------
function pushbuttonDeleteFunc_Callback(hObject, eventdata, handles)
global procStreamEdit
iPanel = procStreamEdit.iPanel;
listPsUsage = procStreamEdit.listPsUsage;

if isempty(listPsUsage)
    MessageBox('Processing stream is empty. Please load or create a processing stream before using Delete button.', 'OK');
    return;
end

iFcall = get(handles.listboxFuncProcStream(iPanel), 'value');
listPsUsage(iPanel).Delete(iFcall);
listPsUsage(iPanel).Tabularize();
updateProcStreamListbox(handles,iPanel);
uicontrol(handles.listboxFuncProcStream(iPanel));



% -------------------------------------------------------------
function pushbuttonMoveUp_Callback(hObject, eventdata, handles)
global procStreamEdit
iPanel = procStreamEdit.iPanel;
listPsUsage = procStreamEdit.listPsUsage;

if isempty(listPsUsage)
    MessageBox('Processing stream is empty. Please load or create a processing stream before using Move Up button.');
    return;
end
iFcall = get(handles.listboxFuncProcStream(iPanel),'value');
if iFcall == 0
    return
end
listPsUsage(iPanel).Move(iFcall, iFcall-1);
if iFcall>1
    iFcall=iFcall-1;
end
set(handles.listboxFuncProcStream(iPanel), 'value',iFcall)
set(handles.listboxFuncProcStream(iPanel), 'string',listPsUsage(iPanel).Get())
uicontrol(handles.listboxFuncProcStream(iPanel));



% -------------------------------------------------------------
function pushbuttonMoveDown_Callback(hObject, eventdata, handles)
global procStreamEdit
iPanel = procStreamEdit.iPanel;
listPsUsage = procStreamEdit.listPsUsage;

if isempty(listPsUsage)
    MessageBox('Processing stream is empty. Please load or create a processing stream before using Move Down button.');
    return;
end

iFcall = get(handles.listboxFuncProcStream(iPanel),'value');
if iFcall == 0
    return
end
listPsUsage(iPanel).Move(iFcall, iFcall+1);
if iFcall<listPsUsage(iPanel).GetSize()
    iFcall = iFcall+1;
end
set(handles.listboxFuncProcStream(iPanel), 'value',iFcall)
set(handles.listboxFuncProcStream(iPanel), 'string',listPsUsage(iPanel).Get())
uicontrol(handles.listboxFuncProcStream(iPanel));



% -------------------------------------------------------------
function pushbuttonLoad_Callback(hObject, eventdata, handles)
global procStreamEdit
reg = procStreamEdit.dataTree.reg;
procElem = procStreamEdit.procElem;

if reg.IsEmpty()
    msg{1} = sprintf('Cannot load processing stream because no user functions are registered. ');
    msg{2} = sprintf('Please add user functions to registry before loading processing stream.');
    MessageBox([msg{:}],'OK');
    return;
end

q = MenuBox('Load current processing stream or config file?',{'Current processing stream','Config file','Cancel'});
if q==3
    return;
end
reload=false;
if q==1
    reload = true;
elseif q==2
    % load cfg file
    [filename,pathname] = uigetfile( '*.cfg', 'Process Options Config File to Load From?');
    if filename == 0
        return;
    end
    for iPanel=1:length(procElem)
        procElem{iPanel}.LoadProcStreamConfigFile([pathname,filename]);
    end
end
LoadProcStream(handles, reload);



% -------------------------------------------------------------
function pushbuttonSave_Callback(hObject, eventdata, handles)
global procStreamEdit
procElem    = procStreamEdit.procElem;
group       = procStreamEdit.dataTree.group;
listPsUsage = procStreamEdit.listPsUsage;
reg         = procStreamEdit.dataTree.reg;
iGroupPanel = procStreamEdit.iGroupPanel;
iSubjPanel  = procStreamEdit.iSubjPanel;
iRunPanel   = procStreamEdit.iRunPanel;

if isempty(listPsUsage)
    MessageBox('Processing stream is empty. Please load or create a processing stream before saving it.');
    return;
end

q = MenuBox('Save to current processing stream or config file?',{'Current processing stream','Config file','Cancel'});
if q==3
    return;
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% First get the user selection of proc stream function calls from the proc stream listbox 
% (listboxFuncProcStream) and load them into the procElem for all panels.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
for iPanel=1:length(procElem)
    % First clear the existing func call chain for this procElem
    procElem{iPanel}.procStream.ClearFcalls();
    
    % Add each listbox selection to the procElem{iPanel}.procStream list 
    % of function calls
    for jj=1:listPsUsage(iPanel).GetSize()
        selection = listPsUsage(iPanel).GetVal(jj);
        parts = str2cell(selection,':');
        if length(parts)<2
            fprintf('#%d: %s does not seem to be a valid selection. Skipping ...\n', jj, selection);
            continue;
        end
        funcname = strtrim(parts{1});
        usagename = strtrim(parts{2});
        fcall = reg.funcReg(MapRegIdx(iPanel)).GetFuncCallDecoded(funcname, usagename);
        procElem{iPanel}.procStream.Add(fcall);
    end
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Now save procElem to current procStream or to  a config file.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if q==1
    group.CopyFcalls(procElem{iGroupPanel});
    group.CopyFcalls(procElem{iSubjPanel});
    group.CopyFcalls(procElem{iRunPanel});
    procStreamEdit.updateParentGui('ProcStreamEditGUI');
elseif q==2
    % load cfg file
    [filename,pathname] = uiputfile( '*.cfg', 'Process Options Config File to Save To?');
    if filename == 0
        return;
    end
    for iPanel=1:length(procElem)
        procElem{iPanel}.SaveProcStreamConfigFile([pathname,filename]);
    end
end



% -------------------------------------------------
function helptxt = LookupHelp(iPanel, name, handles)
global procStreamEdit
reg = procStreamEdit.dataTree.reg;

helptxt = '';
if isempty(reg)
    return;
end
if ischar(name)
    [~,idx] = reg.funcReg(MapRegIdx(iPanel)).GetFuncName(strtrim(name));
elseif iswholenum(name)&& name>0
    idx = name;
end
helptxt = sprintf('%s\n', reg.funcReg(MapRegIdx(iPanel)).GetFuncHelp(idx));
set(handles.textHelp(iPanel), 'string',helptxt);
set(handles.textHelp(iPanel), 'value',1);



% -------------------------------------------------
function helptxt = LookupHelpFuncCall(iPanel, usagename, handles)
global procStreamEdit
reg = procStreamEdit.dataTree.reg;

helptxt = '';
foo = str2cell(usagename, ':');
if isempty(foo) || ~iscell(foo) || ~ischar(foo{1})
    return;
end
if length(foo)<2
    set(handles.textHelp(iPanel), 'value',1);
    set(handles.textHelp(iPanel), 'string','Function call was NOT found in Registry.');
    return;
end
funcname  = strtrim(foo{1});
fcallname = strtrim(foo{2});

fcallstr = reg.funcReg(MapRegIdx(iPanel)).GetFuncCallStrDecoded(funcname, fcallname);
paramtxt = reg.funcReg(MapRegIdx(iPanel)).GetParamText(funcname);
helptxt = sprintf('%s\n\n%s\n', fcallstr, paramtxt);
set(handles.textHelp(iPanel), 'string',helptxt);
setListboxValueToLast(handles.textHelp(iPanel));



% --------------------------------------------------------------------
function uitabRun_ButtonDownFcn(hObject, eventdata, handles)
global procStreamEdit
procStreamEdit.iPanel = procStreamEdit.iRunPanel;
iPanel = procStreamEdit.iPanel;

helptxt = get(handles.textHelp(iPanel),'string');
if isempty(helptxt)
    iFunc = get(handles.listboxFuncReg(iPanel),'value');
    LookupHelp(iPanel, iFunc, handles);
end


% --------------------------------------------------------------------
function uitabSubj_ButtonDownFcn(hObject, eventdata, handles)
global procStreamEdit
procStreamEdit.iPanel = procStreamEdit.iSubjPanel;
iPanel = procStreamEdit.iPanel;

helptxt = get(handles.textHelp(iPanel),'string');
if isempty(helptxt)
    iFunc = get(handles.listboxFuncReg(iPanel),'value');
    LookupHelp(iPanel, iFunc, handles);
end


% --------------------------------------------------------------------
function uitabGroup_ButtonDownFcn(hObject, eventdata, handles)
global procStreamEdit
procStreamEdit.iPanel = procStreamEdit.iGroupPanel;
iPanel = procStreamEdit.iPanel;

helptxt = get(handles.textHelp(iPanel),'string');
if isempty(helptxt)
    iFunc = get(handles.listboxFuncReg(iPanel),'value');
    LookupHelp(iPanel, iFunc, handles);
end



% --------------------------------------------------------------------
function updateProcStreamListbox(handles, iPanel, iFcall)
global procStreamEdit
listPsUsage = procStreamEdit.listPsUsage;

if ~exist('iPanel','var')
    iPanel=1:length(procStreamEdit.procElem);
end
for ii=iPanel
    if ~exist('iFcall','var')
        iFcall = get(handles.listboxFuncProcStream(ii),'value');
    end
    if iFcall>listPsUsage(ii).GetSize()
        iFcall = listPsUsage(ii).GetSize();
    end
    if iFcall<1
        iFcall=1;
    end
    set(handles.listboxFuncProcStream(ii), 'value',iFcall)
    set(handles.listboxFuncProcStream(ii), 'string',listPsUsage(ii).Get())    
end


% --------------------------------------------------------------------
function pushbuttonClearProcStream_Callback(hObject, eventdata, handles)
global procStreamEdit

for iPanel=1:length(procStreamEdit.listPsUsage)
    procStreamEdit.listPsUsage(iPanel).Initialize();
    updateProcStreamListbox(handles, iPanel);
end



% --------------------------------------------------------------------
function ProcStreamEditGUI_Update(handles)
global procStreamEdit



% --------------------------------------------------------------------
function pushbuttonExit_Callback(hObject, eventdata, handles)
if ishandles(handles.figure)
    delete(handles.figure);
end


% --------------------------------------------------------------------
function menuItemChangeGroup_Callback(hObject, eventdata, handles)
pathname = uigetdir(pwd, 'Select a NIRS data group folder');
if pathname==0
    return;
end
cd(pathname);
ProcStreamEditGUI();



% --------------------------------------------------------------------
function menuItemSaveGroup_Callback(hObject, eventdata, handles)
global procStreamEdit
if ~ishandles(hObject)
    return;
end
procStreamEdit.dataTree.currElem.Save();



% --------------------------------------------------------------------
function menuItemImportUserFunction_Callback(hObject, eventdata, handles)
global procStreamEdit
if ~ishandles(hObject)
    return;
end
[fname, pname] = uigetfile('*.m', 'Select user-defined function to import to Function Registry');
if fname == 0 
    return;
end
fullpath = [pname, fname];
fullpath(fullpath=='\') = '/';

% Update registry
procStreamEdit.dataTree.reg.Import(fullpath);

% Reload the registry display in this GUI
LoadRegistry(handles);



% --------------------------------------------------------------------
function menuItemReloadRegistry_Callback(hObject, eventdata, handles)
global procStreamEdit
if ~ishandles(hObject)
    return;
end

% Update registry
procStreamEdit.dataTree.reg.Reload();

% Reload the registry display in this GUI
LoadRegistry(handles);

