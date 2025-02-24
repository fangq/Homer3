classdef ProcStreamClass < handle
    
    properties
        fcalls;                  % Array of FuncCallClass objects representing function call chain i.e. processing stream
        fcallsIdxs;
        reg; 
        input;
        output;
        config;
    end
    
    methods
        
        % ----------------------------------------------------------------------------------
        function obj = ProcStreamClass(acquired)
            if nargin<1
                acquired=[];
            end
            obj.fcalls = FuncCallClass().empty();
            obj.fcallsIdxs = [];
            obj.config = struct('procStreamCfgFile','', 'defaultProcStream','','suffix','');
            cfg = ConfigFileClass();
            obj.config.procStreamCfgFile = cfg.GetValue('Processing Stream Config File');
            copyOptions = '';
            if strcmpi(obj.getDefaultProcStream(), '_nirs')
                copyOptions = 'extended';
            end
            
            % By the time this class constructor is called we should alreadey have a saved registry 
            % to load. (Defintiely would not want to be generating the registry for each instance of this class!!)
            obj.reg = RegistriesClass();
            
            obj.input = ProcInputClass(acquired, copyOptions);
            obj.output = ProcResultClass();
            
            if nargin==0
                return;
            end
            obj.CreateDefault();
        end
        
        
        % ----------------------------------------------------------------------------------
        function Copy(obj, obj2)
            if ~isa(obj, 'ProcStreamClass')
                return;
            end
            
            if isempty(obj)
                obj = ProcStreamClass();
            end
            
            for ii=1:length(obj2.fcalls)
                if ii>length(obj.fcalls)
                    obj.fcalls(ii) = FuncCallClass();
                end
                obj.fcalls(ii).Copy(obj2.fcalls(ii), obj.reg);
            end
            
            % Delete any fcalls entries not ovewritten by the copy process
            obj.fcalls(ii+1:end) = [];
            
            obj.input.Copy(obj2.input);
            obj.output.Copy(obj2.output);
        end
        
        
        % ----------------------------------------------------------------------------------
        function CopyFcalls(obj, obj2)
            if ~isa(obj, 'ProcStreamClass')
                return;
            end
            if nargin<3
                reg = RegistriesClass.empty();
            end            
            delete(obj.fcalls);
            obj.fcalls = FuncCallClass().empty();
            for ii=1:length(obj2.fcalls)
                obj.fcalls(ii) = FuncCallClass();
                obj.fcalls(ii).Copy(obj2.fcalls(ii), obj.reg);
            end
        end
        
        

        % ----------------------------------------------------------------------------------
        function B = eq(obj, obj2)
            B = 0;
            if isa(obj2, 'ProcStream')
                for ii=1:length(obj.fcalls)
                    if ii>length(obj2.fcalls)
                        return
                    end
                    if obj.fcalls(ii) ~= obj2.fcalls(ii)
                        return;
                    end
                end
            elseif isstruct(obj2)
                if ~isproperty(obj2, 'procFunc')
                    return;
                end
                if ~isproperty(obj2.procFunc, 'funcName')
                    return;
                end
                if ~isproperty(obj2.procFunc, 'funcArgOut')
                    return;
                end
                if ~isproperty(obj2.procFunc, 'funcArgIn')
                    return;
                end
                if ~isproperty(obj2.procFunc, 'funcParam')
                    return;
                end
                if ~isproperty(obj2.procFunc, 'funcParamFormat')
                    return;
                end
                if ~isproperty(obj2.procFunc, 'funcParamVal')
                    return;
                end
                if length(obj.fcalls) ~= length(obj2.procFunc.funcName)
                    return;
                end
                for ii=1:length(obj.fcalls)
                    obj3.funcName        = obj2.procFunc.funcName{ii};
                    obj3.funcNameUI      = obj2.procFunc.funcNameUI{ii};
                    obj3.funcArgOut      = obj2.procFunc.funcArgOut{ii};
                    obj3.funcArgIn       = obj2.procFunc.funcArgIn{ii};
                    obj3.nFuncParam      = obj2.procFunc.nFuncParam(ii);
                    obj3.funcParam       = obj2.procFunc.funcParam{ii};
                    obj3.funcParamFormat = obj2.procFunc.funcParamFormat{ii};
                    obj3.funcParamVal    = obj2.procFunc.funcParamVal{ii};
                    B = obj.fcalls(ii) == obj3;
                    if B ~= 1
                        return;
                    end
                end
            end
            B = 1;
        end

        
        % ----------------------------------------------------------------------------------
        function str = EditParam(obj, iFcall, iParam, val)
            str = '';
            if isempty(iFcall)
                return;
            end
            if isempty(iParam)
                return;
            end
            if isempty(obj.fcalls)
                return;
            end
            if isempty(obj.fcalls(iFcall).paramIn)
                return;
            end
            obj.fcalls(iFcall).paramIn(iParam).value = val;
            str = sprintf(obj.fcalls(iFcall).paramIn(iParam).format, val);
        end


        % ----------------------------------------------------------------------------------
        function FcallsIdxs = GetFcallsIdxs(obj)
            nFcall = obj.GetFuncCallNum();
            if isempty(obj.fcallsIdxs)
                FcallsIdxs = 1:nFcall;
            else
                FcallsIdxs = obj.fcallsIdxs;
            end
        end        
        
        
        % ----------------------------------------------------------------------------------
        function Calc(obj)
            DEBUG = 0;
            
            % loop over functions            
            FcallsIdxs = obj.GetFcallsIdxs();
            nFcall = length(FcallsIdxs);
            
            paramOut = {};
            hwait = waitbar(0, 'Processing...' );
            for iFcall = FcallsIdxs
                waitbar( iFcall/nFcall, hwait, sprintf('Processing... %s', obj.GetFcallNamePrettyPrint(iFcall)) );
                
                % Parse obj.input arguments
                argIn = obj.GetInputArgs(iFcall);
                for ii = 1:length(argIn)
                    if ~exist(argIn{ii},'var')
                        eval(sprintf('%s = obj.input.GetVar(''%s'');', argIn{ii}, argIn{ii}));
                    end
                end
                
                % Parse obj.input parameters
                [sargin, p, sarginVal] = obj.ParseInputParams(iFcall);
                
                % Parse obj.input output arguments
                sargout = obj.ParseOutputArgs(iFcall);
                
                % call function
                fcall = sprintf('%s = %s%s%s);', sargout, obj.GetFuncCallName(iFcall), obj.fcalls(iFcall).argIn.str, sargin);
                if DEBUG
                    fprintf('%s = %s%s%s);\n', sargout, obj.GetFuncCallName(iFcall), obj.fcalls(iFcall).argIn.str, sarginVal);
                end
                try
                    eval( fcall );
                catch ME
                    msg = sprintf('Function %s generated error at line %d: %s', obj.fcalls(iFcall).name, ME.stack(1).line, ME.message);
                    menu(msg,'OK');
                    close(hwait);
                    assert(false, msg);
                end
                
                %%%% Parse output parameters
                
                % remove '[', ']', and ','
                foos = obj.fcalls(iFcall).argOut.str;
                for ii=1:length(foos)
                    if foos(ii)=='[' | foos(ii)==']' | foos(ii)==',' | foos(ii)=='#'
                        foos(ii) = ' ';
                    end
                end
                
                % get parameters for Output to obj.output
                lst = strfind(foos,' ');
                lst = [0, lst, length(foos)+1];
                for ii=1:length(lst)-1
                    foo2 = foos(lst(ii)+1:lst(ii+1)-1);
                    lst2 = strmatch( foo2, paramOut, 'exact' );
                    idx = strfind(foo2,'foo');
                    if isempty(lst2) & (isempty(idx) || idx>1) & ~isempty(foo2)
                        paramOut{end+1} = foo2;
                    end
                end
            end
            
            % Copy paramOut to output
            for ii=1:length(paramOut)
                if eval( sprintf('isproperty(obj.output, ''%s'');', paramOut{ii}) )
                    eval( sprintf('obj.output.%s = %s;', paramOut{ii}, paramOut{ii}) );
                else
                    eval( sprintf('obj.output.misc.%s = %s;', paramOut{ii}, paramOut{ii}) );
                end
            end
            obj.input.misc = [];
            close(hwait);
            
            if DEBUG
                fprintf('\n');
            end
            
        end
        
        
        % ----------------------------------------------------------------------------------
        function FcallsIdxsTimeCourses(obj)
            if ~obj.output.HaveBlockAvgOutput()
                return;
            end
            idxs = zeros(1, length(obj.fcalls));
            for ii=1:length(obj.fcalls)
                sargout = ParseOutputArgs(obj, ii);
                if strfind('dod', sargout)
                    idxs(ii) = 1;
                end
                if strfind('dc', sargout)
                    idxs(ii) = 1;
                end
            end
            k = find(idxs==1);
            obj.fcallsIdxs=1:k(end);
        end
                
        
        
        % ----------------------------------------------------------------------------------
        function FcallsIdxsReset(obj)
            obj.fcallsIdxs=[];            
        end
        
        
        % ----------------------------------------------------------------------------------
        function b = IsEmpty(obj)
            b=0;
            if isempty(obj)
                return
            end
            if isempty(obj.fcalls)
                b=1;
                return;
            end
            if isempty(obj.input)
                b=1;
                return;
            end
            if isempty(obj.output)
                b=1;
                return;
            end
            
            % Now that we know we have a non-empty fcalls, check to see if at least
            % one VALID function is present
            b=1;
            for ii=1:length(obj.fcalls)
                if ~isempty(obj.fcalls(ii).name) && ~isempty(obj.fcalls(ii).argOut.str)
                    b=0;
                    return;
                end
            end
        end
        
        
        
        % ----------------------------------------------------------------------------------
        function b = HaveBlockAvgOutput(obj)
            b=0;
            if isempty(obj)
                return;
            end
            if isempty(obj.output)
                return;
            end
            b = obj.output.HaveBlockAvgOutput();
        end
        
        
        
        % ----------------------------------------------------------------------------------
        function b = HaveTimeCourseOutput(obj)
            b=0;
            if isempty(obj)
                return;
            end
            if isempty(obj.output)
                return;
            end
            b = obj.output.HaveTimeCourseOutput();
        end
        
        
        
        % ----------------------------------------------------------------------------------
        function [args, type] = GetInputArgs(obj, iFcall)
            args={};
            type={};
            if isempty(obj.fcalls)
                return;
            end
            if ~exist('iFcall', 'var') || isempty(iFcall)
                iFcall = obj.GetFcallsIdxs();
            end
            nFcall = length(obj.fcalls);

            kk=1;
            for jj=1:length(iFcall)
                if iFcall(jj)>nFcall
                    continue;
                end
                if obj.fcalls(iFcall(jj)).argIn.str(1) ~= '('
                    continue;
                end
                j=2;
                k = [strfind(obj.fcalls(iFcall(jj)).argIn.str,',') length(obj.fcalls(iFcall(jj)).argIn.str)+1];
                for ii=1:length(k)
                    args{kk} = obj.fcalls(iFcall(jj)).argIn.str(j:k(ii)-1);
                    j = k(ii)+1;
                    kk=kk+1;
                end
            end
            args = unique(args, 'stable');
        end
        
        
        % ----------------------------------------------------------------------------------
        function [sargin, p, sarginVal] = ParseInputParams(obj, iFcall)
            sargin = '';
            sarginVal = '';
            nParam = length(obj.fcalls(iFcall).paramIn);            
            p = cell(nParam, 1);

            if isempty(obj.fcalls)
                return;
            end
            if iFcall>length(obj.fcalls)
                return;
            end            
            for iP = 1:nParam
                p{iP} = obj.fcalls(iFcall).paramIn(iP).value;
                if length(obj.fcalls(iFcall).argIn.str)==1 & iP==1
                    sargin = sprintf('%sp{%d}', sargin, iP);
                    if isnumeric(p{iP})
                        if length(p{iP})==1
                            sarginVal = sprintf('%s%s', sarginVal, num2str(p{iP}));
                        else
                            sarginVal = sprintf('%s[%s]', sarginVal, num2str(p{iP}));
                        end
                    elseif ~isstruct(p{iP})
                        sarginVal = sprintf('%s,%s', sarginVal, p{iP});
                    else
                        sarginVal = sprintf('%s,[XXX]', sarginVal);
                    end
                else
                    sargin = sprintf('%s,p{%d}', sargin, iP);
                    if isnumeric(p{iP})
                        if length(p{iP})==1
                            sarginVal = sprintf('%s,%s', sarginVal, num2str(p{iP}));
                        else
                            sarginVal = sprintf('%s,[%s]', sarginVal, num2str(p{iP}));
                        end
                    elseif ~isstruct(p{iP})
                        sarginVal = sprintf('%s,%s', sarginVal, p{iP});
                    else
                        sarginVal = sprintf('%s,[XXX]',sarginVal);
                    end
                end
            end
        end
        
        
        % ----------------------------------------------------------------------------------
        function sargout = ParseOutputArgs(obj, iFcall)
            sargout = '';
            if isempty(obj.fcalls)
                return;
            end
            if iFcall>length(obj.fcalls)
                return;
            end            
            sargout = obj.fcalls(iFcall).argOut.str;
            for ii=1:length(obj.fcalls(iFcall).argOut.str)
                if sargout(ii)=='#'
                    sargout(ii) = ' ';
                end
            end
        end
        
        
        % ----------------------------------------------------------------------------------
        function name = GetFuncCallName(obj, iFcall)
            name = '';
            if isempty(obj.fcalls)
                return;                
            end
            if iFcall>length(obj.fcalls)
                return;
            end
            name = obj.fcalls(iFcall).name;
        end
        
        
        % ----------------------------------------------------------------------------------
        function idx = GetFuncCallIdx(obj, name)
            % Find first occurrence of function call with function name
            % <name>
            idx = [];
            if ~ischar(name)
                return;                
            end
            for ii=1:length(obj.fcalls)
                if strcmp(obj.fcalls(ii).name, name)
                    idx=ii;
                    break;
                end
            end
        end
        
        
        % ----------------------------------------------------------------------------------
        function name = GetFcallNamePrettyPrint(obj, iFcall)
            name = '';
            if isempty(obj.fcalls)
                return;                
            end
            if iFcall>length(obj.fcalls)
                return;
            end
            name = sprintf_waitbar(obj.fcalls(iFcall).name);
        end
        
        
        % ----------------------------------------------------------------------------------
        function n = GetFuncCallNum(obj)
            n = length(obj.fcalls);
        end
                
        
        % ----------------------------------------------------------------------------------
        function maxnamelen = GetMaxCallNameLength(obj)
            maxnamelen = 0;
            for iFcall = 1:length(obj.fcalls)
                if length(obj.fcalls(iFcall).GetNameUserFriendly()) > maxnamelen
                    maxnamelen = length(obj.fcalls(iFcall).nameUI)+1;
                end
            end
        end
        
        
        % -----------------------------------------------------------------
        function maxnamelen = GetMaxParamNameLength(obj)
            maxnamelen = 0;
            for iFcall = 1:length(obj.fcalls)
                if obj.fcalls(iFcall).GetMaxParamNameLength() > maxnamelen
                    maxnamelen = obj.fcalls(iFcall).GetMaxParamNameLength();
                end
            end
        end
        
        
        % -----------------------------------------------------------------
        function n = GetParamNum(obj)
            n = zeros(1,length(obj.fcalls));
            for iFcall = 1:length(obj.fcalls)
                n(iFcall) = obj.fcalls(iFcall).GetParamNum();
            end
        end
        
        
        % ----------------------------------------------------------------------------------
        function ClearFcalls(obj)
            delete(obj.fcalls);
            obj.fcalls = FuncCallClass().empty();
        end
                        
    end
    
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Methods for loading / saving proc stream config file.
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    methods

        % ----------------------------------------------------------------------------------
        function [fname, autoGenDefault] = GetConfigFileName(obj, procStreamCfgFile)
            autoGenDefault = false;
            if ~exist('procStreamCfgFile','var')
                procStreamCfgFile = '';
            end
            
            % If procStream config filename wasn't passed down as an argument, check the 
            % parent application AppSettings.cfg config file to see if it set there. 
            if isempty(procStreamCfgFile)
                if ~isempty(obj.config.procStreamCfgFile)
                    procStreamCfgFile = obj.config.procStreamCfgFile;
                else
                    procStreamCfgFile = 'processOpt_default.cfg';
                end
            end

            % Check if file with name procStreamCfgFile exists
            temp = FileClass();
            if temp.Exist(procStreamCfgFile)
                fname = procStreamCfgFile;
                fprintf('Default config file exists. Processing stream will be loaded from %s\n', procStreamCfgFile, procStreamCfgFile);
                return;
            end
            
            % This pause is a workaround for a matlab bug in version
            % 7.11 for Linux, where uigetfile won't block unless there's
            % a breakpoint.
            pause(.5);
            [fname, pname] = uigetfile('*.cfg', 'Load Process Options File' );
            if fname==0
                MessageBox( sprintf('Loading default config file.'),'Creating default config');
                fname = [pwd, '/', procStreamCfgFile];
                autoGenDefault = true;
            else
                fname = [pname, fname];
            end
            fname(fname=='\')='/';
        end
        
        
        % ----------------------------------------------------------------------------------
        function err = LoadConfigFile(obj, fname, type)
            % Syntax:
            %   err = obj.LoadConfigFile(fname)
            %   err = obj.LoadConfigFile(fname, type)
            %
            % Description:
            %   Load proc stream function call chain from config file with name fname
            %   into ProcStreamClass object. If type argument isn't provided the class 
            %   defaults to run-level (type = 'run') and will load that section's call chain. 
            %
            % Example:
            %
            %   % Load function call chains at all levels from the config file 
            %   % processOpt_default_homer3.cfg to three instances of ProcStreamClass 
            %   pGroup = ProcStreamClass();
            %   pGroup.LoadConfigFile('processOpt_default_homer3.cfg', [], 'group');
            %   pSubj = ProcStreamClass();
            %   pSubj.LoadConfigFile('processOpt_default_homer3.cfg', [], 'subj');
            %   pRun = ProcStreamClass();
            %   pRun.LoadConfigFile('processOpt_default_homer3.cfg', [], 'run');
            %
            %   Here's what pSubj looks like:
            %
            %   pSubj =
            %
            %      ProcStreamClass with properties:
            %
            %            fcalls: [1x1 FuncCallClass]
            %           tIncMan: []
            %              misc: []
            %        changeFlag: 0
            %
            %   pSubj.fcalls = 
            %
            %       FuncCallClass with properties:
            %
            %              name: 'hmrS_RunAvg'
            %            nameUI: 'hmrS_RunAvg'
            %            argOut: '[dcAvg,dcAvgStd,tHRF,nTrials]'
            %             argIn: '(dcAvgRuns,dcAvgStdRuns,dcSum2Runs,tHRFRuns,SDRuns,nTrialsRuns'
            %           paramIn: [0x0 ParamClass]
            %              help: '  Calculate the block average for all subjects, for all common stimuli�'
            %
            err = -1;
            if ~exist('fname', 'var')
                fname = '';
            end
            if ~exist('type', 'var') || isempty(type)
                type = 'run';
            end
            fid = fopen(fname);
            if fid<0
                return;
            end
            
            % Reinitialize fcalls since we're going to overwrite them anyway
            obj.fcalls = FuncCallClass().empty();
            obj.ParseFile(fid, type);
            fclose(fid);
            err=0;            
        end
        
        
        
        % ----------------------------------------------------------------------------------
        function err = SaveConfigFile(obj, fname, type)
            % Syntax:
            %   err = obj.SaveConfigFile(fname)
            %   err = obj.SaveConfigFile(fname, type)
            %
            % Description:
            %   Save this ProcStreamClass function call chain to config file fname. If type argument 
            %   isn't provided the class defaults to run-level (type = 'run'). The ProcStreamClass 
            %   object is not associated with a processing level - all it knows is it's 
            %   function call chain. It needs the type argument when saving
            %   to know how to label  
            %   the section it's saving in the file. It writes that header as '% <section name>' before
            %   the list of function call strings beginning with '@ '.
            %
            %   If the file already exists and has a config section for the same processing level, it 
            %   completetly replaces that section of the config file, leaving the other sections 
            %   untouched. 
            %
            % Example:
            %
            %   Create a processing config file for all processing levels. 
            %
            %   pInputR = ProcStreamClass();
            %   pInputR.LoadConfigFile('processOpt.cfg', 'run');
            %
            %   pInputS = ProcStreamClass();
            %   pInputS.LoadConfigFile('processOpt.cfg', 'subj');
            %
            %   pInputG = ProcStreamClass();
            %   pInputG.LoadConfigFile('processOpt.cfg', 'group');
            %
            %   pInputG.SaveConfigFile('./processOpt_new.cfg', 'group');
            %   pInputS.SaveConfigFile('./processOpt_new.cfg', 'subj');
            %   pInputR.SaveConfigFile('./processOpt_new.cfg', 'run');
            %
            err = -1;
            if ~exist('fname', 'var')
                fname = '';
            end
            if ~exist('type', 'var') || isempty(type)
                type = 'run';
            end
            versionstamp = sprintf('%% %s\n', MainGUIVersion('exclpath'));

            % First read in and parse existing file contents
            if ~exist(fname, 'file')
                readoption = 'w+';
            else
                readoption = 'r';                
            end            
            fid = fopen(fname,readoption);
            if fid<0
                return;
            end
            [G, S, R] = obj.FindSections(fid, 'nodefault');
            fclose(fid);
            
            % Construct new contents
            switch(lower(type))
                case {'group', 'groupclass', 'grp'}
                    G = [ sprintf('%% group'); obj.GenerateSection(); sprintf('\n') ];
                    S = [ sprintf('%% subj');  S; sprintf('\n') ];
                    R = [ sprintf('%% run');   R; sprintf('\n') ];
                case {'subj', 'session', 'subjclass'}
                    G = [ sprintf('%% group'); G; sprintf('\n') ];
                    S = [ sprintf('%% subj');  obj.GenerateSection(); sprintf('\n') ];
                    R = [ sprintf('%% run');   R; sprintf('\n') ];
                case {'run', 'runclass'}
                    G = [ sprintf('%% group'); G; sprintf('\n') ];
                    S = [ sprintf('%% subj');  S; sprintf('\n') ];
                    R = [ sprintf('%% run');   obj.GenerateSection(); sprintf('\n') ];
                otherwise
                    return;
            end
            newcontents = [versionstamp; G; S; R];
            
            % Write new contents to file 
            fid = fopen(fname,'w');
            for ii=1:length(newcontents)
                fprintf(fid, '%s\n', newcontents{ii});
            end
            fclose(fid);
            
            err=0;
        end
        
        
        % ---------------------------------------------------------------------
        % Function to extract the 3 proc stream sections - group, subj, and run -
        % from a processing stream config cell array.
        % ---------------------------------------------------------------------
        function [G, S, R] = FindSections(obj, fid, mode)
            %
            % Syntax:
            %    [G, S, R] = obj.FindSections(fid, mode)
            %
            % Description:
            %    Read in proc stream config file with file descriptor fid and returns the 
            %    group (G), subject (S) and run (R) sections. A section is a cell array of 
            %    encoded function call strings. If mode is 'default' then for a missing 
            %    section a default section is generated, otherwise it is left empty. 
            %
            % Example: 
            %    fid = fopen('processOpt_ShortSep.cfg');
            %    p = ProcStreamClass();
            %    [G, S, R] = p.FindSections(fid);
            %    fclose(fid);
            %
            %    Here's the output:
            %
            %     G = {
            %          '@ hmrG_SubjAvg [dcAvg,dcAvgStd,nTrials,grpAvgPass] (dcAvgSubjs,dcAvgStdSubjs,SDSubjs,nTrialsSubjs tRange %0.1f�'
            %         }
            %     S = {
            %          '@ hmrS_RunAvg [dcAvg,dcAvgStd,nTrials] (dcAvgRuns,dcAvgStdRuns,dcSum2Runs,SDRuns,nTrialsRuns'
            %         }
            %     R = {
            %         '@ hmrR_Intensity2OD dod (d'
            %         '@ hmrR_MotionArtifact tIncAuto (dod,t,SD,tIncMan tMotion %0.1f 0.5 tMask %0.1f 1.0 STDEVthresh %0.1f 50.0 AMPthresh %0.1f 5.0'
            %         '@ hmrR_BandpassFilt dod (dod,t hpf %0.3f 0.010 lpf %0.3f 0.500'
            %         '@ hmrR_OD2Conc dc (dod,SD ppf %0.1f_%0.1f 6.0_6.0'
            %         '@ hmrR_DeconvHRF_DriftSS [dcAvg,dcAvgstd,tHRF,nTrials,ynew,yresid,ysum2,beta,R] (dc,s,t,SD,aux,tIncAuto trange %0.1f_%0.1f -2.0_20.0 glmSolv�'
            %         }
            % 
            if ~exist('mode','var') || isempty(mode) || ~ischar(mode)
                mode = 'default';
            end
            
            G = {};
            S = {};
            R = {};
            if ~iswholenum(fid) || fid<0
                return;
            end
            iG=1; iS=1; iR=1;
            section = 'run';   % Run is the default is sections aren't labeled
            while ~feof(fid)
                ln = fgetl(fid);
                if isempty(ln) || ~ischar(ln)
                    continue;
                end
                ln = strtrim(ln);
                if ln(1)=='%'
                    str = strtrim(ln(2:end));
                    switch(lower(str))
                        case {'group','grp'}
                            section = str;
                        case {'subj','subject','session','sess'}
                            section = str;
                        case {'run'}
                            section = str;
                    end
                elseif ln(1)=='@'
                    switch(lower(section))
                        case {'group','grp'}
                            G{iG,1} = strtrim(ln); iG=iG+1;
                        case {'subj','subject','session','sess'}
                            S{iS,1} = strtrim(ln); iS=iS+1;
                        case {'run'}
                            R{iR,1} = strtrim(ln); iR=iR+1;
                    end
                end
            end
            
            % Generate default contents for all sections which are missing
            if strcmp(mode, 'default')
                if isempty(G)
                    G = obj.fcallStrEncodedGroup;
                end
                if isempty(S)
                    S = obj.fcallStrEncodedSubj;
                end
                if isempty(R)
                    R = obj.fcallStrEncodedRun;
                end
            end
        end
        
        
        
        % ----------------------------------------------------------------------------------
        function section = GenerateSection(obj)
            %
            % Syntax:
            %    section = obj.GenerateSection()
            %
            % Description:

            %
            % Example: 
            %
            %    % Load run section into p from processOpt_default.cfg
            %    p = ProcStreamClass();
            %    p.LoadConfigFile('processOpt_default.cfg')
            %    R = obj.GenerateSection();
            %
            %    Here's the output:
            %
            %     R = {
            %         '@ hmrR_Intensity2OD dod (d'
            %         '@ hmrR_MotionArtifact tIncAuto (dod,t,SD,tIncMan tMotion %0.1f 0.5 tMask %0.1f 1.0 STDEVthresh %0.1f 50.0 AMPthresh %0.1f 5.0'
            %         '@ hmrR_BandpassFilt dod (dod,t hpf %0.3f 0.010 lpf %0.3f 0.500'
            %         '@ hmrR_OD2Conc dc (dod,SD ppf %0.1f_%0.1f 6.0_6.0'
            %         '@ hmrR_DeconvHRF_DriftSS [dcAvg,dcAvgstd,tHRF,nTrials,ynew,yresid,ysum2,beta,R] (dc,s,t,SD,aux,tIncAuto trange %0.1f_%0.1f -2.0_20.0 glmSolv�'
            %         }
            %
            section = cell(length(obj.fcalls), 1);
            for ii=1:length(obj.fcalls)
                section{ii} = obj.fcalls(ii).Encode();
            end
        end
        
        
        
        % ----------------------------------------------------------------------------------
        function err = ParseFile(obj, fid, type)
            %
            % Processing stream config file parser. This function handles
            % group, subj and run processing stream parameters
            %
            % Example:
            %  
            %    Create a ProcStreamClass object and load the function calls
            %    from the proc stream config file './processOpt_default.cfg'
            % 
            %    fid = fopen('./processOpt_default.cfg');
            %    p = ProcStreamClass();
            %    p.ParseFile(fid, 'run');
            %    fclose(fid);
            %
            %    Here's some of the output 
            %
            %    p
            %
            %        ===> ProcStreamClass with properties:
            %
            %            fcalls: [1x6 FuncCallClass]
            %           tIncMan: []
            %              misc: []
            %        changeFlag: 0
            % 
            %    p.fcalls(2)
            %     
            %        ===> FuncCallClass with properties:
            %
            %              name: 'hmrR_MotionArtifact'
            %            nameUI: 'hmrR_MotionArtifact'
            %            argOut: 'tIncAuto'
            %             argIn: '(dod,t,SD,tIncMan'
            %           paramIn: [1x4 ParamClass]
            %              help: '  Excludes stims that fall within the time points identified as �'
            %
            %    p.fcalls(3)
            %     
            %        ===> FuncCallClass with properties:
            %
            %              name: 'hmrR_StimRejection'
            %            nameUI: 'hmrR_StimRejection'
            %            argOut: '[s,tRangeStimReject]'
            %             argIn: '(t,s,tIncAuto,tIncMan'
            %           paramIn: [1x1 ParamClass]
            %              help: '  Excludes stims that fall within the time points identified as �'
            %
            
            err=-1;
            if ~exist('fid','var') || ~iswholenum(fid) || fid<0
                return;
            end
            if ~exist('type','var')
                return;
            end
            [G, S, R] = obj.FindSections(fid);
            switch(lower(type))
                case {'group', 'groupclass', 'grp'}
                    obj.Decode(G);
                case {'subj', 'session', 'subjclass'}
                    obj.Decode(S);
                case {'run', 'runclass'}
                    obj.Decode(R);
                otherwise
                    return;
            end
            err=0;
        end
        
        
        % ----------------------------------------------------------------------------------
        function Decode(obj, section)
            % Syntax:
            %    obj.Decode(section)
            %    
            % Description:
            %    Parse a cell array of strings, each string an encoded hmr*.m function call
            %    and into the FuncCallClass array of this ProcStreamClass object. 
            %
            % Input: 
            %    A section contains encoded strings for one or more hmr* user function calls.
            %   
            % Example:
            %
            %    fcallStrs{1} = '@ hmrR_BandpassFilt dod (dod,t hpf %0.3f 0.010 lpf %0.3f 0.500';
            %    fcallStrs{2} = '@ hmrR_OD2Conc dc (dod,SD ppf %0.1f_%0.1f 6_6';
            %
            %    p = ProcStreamClass();
            %    p.Decode(fcallStrs);
            % 
            %    Here's the output:
            % 
            %    p.fcalls(1)
            %
            %      ===> FuncCallClass with properties:
            %
            %          name: 'hmrR_BandpassFilt'
            %        nameUI: 'hmrR_BandpassFilt'
            %        argOut: 'dod'
            %         argIn: '(dod,t'
            %       paramIn: [1x2 ParamClass]
            %          help: '  Perform a bandpass filter�'
            %
            %    p.fcalls(2)
            %
            %      ===> FuncCallClass with properties:
            %
            %          name: 'hmrR_OD2Conc'
            %        nameUI: 'hmrR_OD2Conc'
            %        argOut: 'dc'
            %         argIn: '(dod,SD'
            %       paramIn: [1x1 ParamClass]
            %          help: '  Convert OD to concentrations�'
            % 
            if nargin<2
                return
            end
            
            if ~iscell(section)
                if ~ischar(section)
                    return;
                else
                    section = {section};
                end
            end

            kk=1;
            for ii=1:length(section)
                if section{ii}(1)=='%'
                    continue;
                end
                if section{ii}(1)=='@'
                    temp = FuncCallClass(section{ii});
                    
                    % If registry is empty, then add fcall entries unconditionally. 
                    % Otherwise only include those user function calls that exist in the registry. 
                    if temp.GetErr()==0 && ~isempty(obj.reg.GetUsageName(temp))
                        obj.fcalls(kk) = FuncCallClass(temp, obj.reg);
                        kk=kk+1;
                    else
                        fprintf('Entry not found in registry: "%s"\n', section{ii})
                    end
                end
            end            
        end
        

        
        % ----------------------------------------------------------------------------------
        function Add(obj, new)
            idx = length(obj.fcalls)+1;
            obj.fcalls(idx) = FuncCallClass(new, obj.reg);
        end
        
        
        % ----------------------------------------------------------------------------------
        function section = Encode(obj)
            % Syntax:
            %    section = obj.Encode()
            % 
            % Description:
            %    Generate a cell array of encoded string function calls from 
            %    the FuncCallClass array of this ProcStreamClass object. 
            %
            % Input:
            %    A section contains encoded strings for one or more hmr* user function calls.
            %   
            % Example:
            %
            %    fcallStrs{1} = '@ hmrR_BandpassFilt dod (dod,t hpf %0.3f 0.010 lpf %0.3f 0.500';
            %    fcallStrs{2} = '@ hmrR_OD2Conc dc (dod,SD ppf %0.1f_%0.1f 6_6';
            %
            %    p = ProcStreamClass();
            %    p.Decode(fcallStrs);
            %    fcallStrs2 = p.Encode();
            %
            %
            section = cell(length(obj.fcalls), 1);
            for ii=1:length(obj.fcalls)
                section{ii} = obj.fcalls(ii).Encode();
            end
        end
        
    end

    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Methods for dealing with default proc input 
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    methods

        % ----------------------------------------------------------------------------------
        function CreateDefault(obj)
            obj.fcallStrEncodedGroup('init');
            obj.fcallStrEncodedSubj('init');
            obj.fcallStrEncodedRun('init');
        end
        
        
        % ----------------------------------------------------------------------------------
        function obj2 = GetDefault(obj, type)
            obj2 = ProcStreamClass();
            switch(lower(type))
                case {'group', 'groupclass'}
                    obj2.Decode(obj.fcallStrEncodedGroup);
                case {'subj', 'session', 'subjclass'}
                    obj2.Decode(obj.fcallStrEncodedSubj);
                case {'run', 'runclass'}
                    obj2.Decode(obj.fcallStrEncodedRun);
                otherwise
                    return;
            end
        end
        
    end
    
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Static methods 
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    methods (Access = private, Static = true)

        % ----------------------------------------------------------------------------------
        function suffix = getDefaultProcStream()
            suffix = '';
            defaultProcStream = ConfigFileClass().GetValue('Default Processing Stream Style');
            if includes(lower(defaultProcStream),'nirs')
                suffix = '_Nirs';
            end
        end
            
    end
    
    
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Methods implementing static variables for this class. The static variable 
    % for this class are the default function call chains for group, subject and run. 
    % There is only one instance of each of these because these variables are the 
    % same for all instances of the ProcStreamClass class
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    methods
        
        % ----------------------------------------------------------------------------------
        function val = fcallStrEncodedGroup(obj, init)
            persistent v;
            if exist('init','var') && strcmp(init,'init')
                iG = obj.reg.igroup;
                suffix = obj.getDefaultProcStream();
                tmp = {...
                    obj.reg.funcReg(iG).GetUsageStrDecorated(['hmrG_SubjAvg',suffix],'dcAvg'); ...
                    obj.reg.funcReg(iG).GetUsageStrDecorated(['hmrG_SubjAvgStd',suffix],'dcAvg'); ...
                };
                k=[]; kk=1;
                for ii=1:length(tmp)
                    if isempty(tmp{ii})
                        k(kk)=ii;
                        kk=kk+1;
                    end
                end
                tmp(k) = [];
                if ~isempty(tmp)
                    v = tmp;
                end
            end
            val = v;
        end
        
        
        % ----------------------------------------------------------------------------------
        function val = fcallStrEncodedSubj(obj, init)
            persistent v;
            if exist('init','var') && strcmp(init,'init')
                iS = obj.reg.isubj;
                suffix = obj.getDefaultProcStream();
                tmp = {...
                    obj.reg.funcReg(iS).GetUsageStrDecorated(['hmrS_RunAvg',suffix],'dcAvg'); ...
                    obj.reg.funcReg(iS).GetUsageStrDecorated(['hmrS_RunAvgStd',suffix],'dcAvg'); ...
                };
                k=[]; kk=1;
                for ii=1:length(tmp)
                    if isempty(tmp{ii})
                        k(kk)=ii;
                        kk=kk+1;
                    end
                end
                tmp(k) = [];
                if ~isempty(tmp)
                    v = tmp;
                end
            end
            val = v;
        end

        
        % ----------------------------------------------------------------------------------
        function val = fcallStrEncodedRun(obj, init)
            persistent v;
            if exist('init','var') && strcmp(init,'init')
                iR = obj.reg.irun;
                suffix = obj.getDefaultProcStream();
                tmp = {...
                    obj.reg.funcReg(iR).GetUsageStrDecorated(['hmrR_Intensity2OD',suffix]); ...
                    obj.reg.funcReg(iR).GetUsageStrDecorated(['hmrR_BandpassFilt',suffix]); ...
                    obj.reg.funcReg(iR).GetUsageStrDecorated(['hmrR_OD2Conc',suffix]); ...
                    obj.reg.funcReg(iR).GetUsageStrDecorated(['hmrR_BlockAvg',suffix],'dcAvg'); ...
                };
                k=[]; kk=1;
                for ii=1:length(tmp)
                    if isempty(tmp{ii})
                        k(kk)=ii;
                        kk=kk+1;
                    end
                end
                tmp(k) = [];
                if ~isempty(tmp)
                    v = tmp;
                end
            end
            val = v;
        end
                
    end
    
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Methods for getting/setting derived parameters 
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    methods
        
        % ----------------------------------------------------------------------------------
        function varval = GetVar(obj, varname, iBlk)
            if ~exist('iBlk','var')
                varval = obj.input.GetVar(varname);
                if isempty(varval)
                    varval = obj.output.GetVar(varname);
                end
            else
                varval = obj.input.GetVar(varname, iBlk);
                if isempty(varval)
                    varval = obj.output.GetVar(varname, iBlk);
                end                
            end
        end
        
        
        % ----------------------------------------------------------------------------------
        function tIncMan = GetTincMan(obj, iBlk)
            if ~exist('iBlk','var')
                iBlk = [];
            end
            tIncMan = obj.input.GetVar('tIncMan', iBlk);
        end
        

        % ----------------------------------------------------------------------------------
        function tIncAuto = GetTincAuto(obj, iBlk)
            if ~exist('iBlk','var')
                iBlk = [];
            end
            tIncAuto = obj.output.GetVar('tIncAuto', iBlk);
        end
        

        % ----------------------------------------------------------------------------------
        function mlActMan = GetMeasListActMan(obj, iBlk)
            if ~exist('iBlk','var')
                iBlk = [];
            end
            mlActMan = obj.input.GetVar('mlActMan',iBlk);
        end
        
        
        % ----------------------------------------------------------------------------------
        function mlActAuto = GetMeasListActAuto(obj, iBlk)
            if ~exist('iBlk','var')
                iBlk = [];
            end
            mlActAuto = obj.output.GetVar('mlActAuto',iBlk);
        end

        
        % ----------------------------------------------------------------------------------
        function mlVis = GetMeasListVis(obj, iBlk)
            if ~exist('iBlk','var')
                iBlk = [];
            end
            mlVis = obj.input.GetVar('mlVis',iBlk);
        end

        
        % ----------------------------------------------------------------------------------
        function pValues = GetPvalues(obj, iBlk)
            if ~exist('iBlk','var')
                iBlk = [];
            end
            pValues = obj.output.GetVar('pValues',iBlk);
        end
        
    end
    
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Methods for getting/setting editable acquisition parameters such as
    % stimulus and source/detector geometry
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    methods
        
        % ----------------------------------------------------------------------------------
        function AddStims(obj, tPts, condition)
            if isempty(tPts)
                return;
            end
            if isempty(condition)
                return;
            end
            obj.input.AddStims(tPts, condition);
        end

        
        % ----------------------------------------------------------------------------------
        function DeleteStims(obj, tPts, condition)
            if ~exist('tPts','var') || isempty(tPts)
                return;
            end
            if ~exist('condition','var')
                condition = '';
            end
            obj.input.DeleteStims(tPts, condition);
        end
        
        
        % ----------------------------------------------------------------------------------
        function MoveStims(obj, tPts, condition)
            if ~exist('tPts','var') || isempty(tPts)
                return;
            end
            if ~exist('condition','var')
                condition = '';
            end
            obj.input.MoveStims(tPts, condition);
        end
        
        
        % ----------------------------------------------------------------------------------
        function [tpts, duration, vals] = GetStimData(obj, icond)
            tpts     = obj.GetStimTpts(icond);
            duration = obj.GetStimDuration(icond);
            vals     = obj.GetStimValues(icond);
        end
        
    
        % ----------------------------------------------------------------------------------
        function SetStimTpts(obj, icond, tpts)
            obj.input.SetStimTpts(icond, tpts);
        end
        
    
        % ----------------------------------------------------------------------------------
        function tpts = GetStimTpts(obj, icond)
            if ~exist('icond','var')
                icond=1;
            end
            tpts = obj.input.GetStimTpts(icond);
        end
        
        
        % ----------------------------------------------------------------------------------
        function SetStimDuration(obj, icond, duration)
            obj.input.SetStimDuration(icond, duration);
        end
        
    
        % ----------------------------------------------------------------------------------
        function duration = GetStimDuration(obj, icond)
            if ~exist('icond','var')
                icond=1;
            end
            duration = obj.input.GetStimDuration(icond);
        end
        
        
        % ----------------------------------------------------------------------------------
        function SetStimValues(obj, icond, vals)
            obj.input.SetStimValues(icond, vals);
        end
        
    
        % ----------------------------------------------------------------------------------
        function vals = GetStimValues(obj, icond)
            if ~exist('icond','var')
                icond=1;
            end
            vals = obj.input.GetStimValues(icond);
        end
                       
        
        % ---------------------------------------------------------
        function CondNames = GetConditions(obj)
            CondNames = obj.input.GetConditions();
        end
        

        % ----------------------------------------------------------------------------------
        function SetConditions(obj, CondNames)
            if nargin==1
                return;
            end
            obj.input.SetConditions(CondNames);
        end
        
        
        % ----------------------------------------------------------------------------------
        function RenameCondition(obj, oldname, newname)
            % Function to rename a condition. Important to remeber that changing the
            % condition involves 2 distinct well defined steps:
            %   a) For the current element change the name of the specified (old)
            %      condition for ONLY for ALL the acquired data elements under the
            %      currElem, be it run, subj, or group. In this step we DO NOT TOUCH
            %      the condition names of the run, subject or group.
            %   b) Rebuild condition names and tables of all the tree nodes group, subjects
            %      and runs same as if you were loading during Homer3 startup from the
            %      acquired data.
            %
            if ~exist('oldname','var') || ~ischar(oldname)
                return;
            end
            if ~exist('newname','var')  || ~ischar(newname)
                return;
            end
            obj.input.RenameCondition(oldname, newname);
        end
        
    end    
    
end

