classdef SubjClass < TreeNodeClass
    
    properties % (Access = private)
        runs;
    end
    
    methods
                
        % ----------------------------------------------------------------------------------
        function obj = SubjClass(varargin)
            obj@TreeNodeClass(varargin);
            
            obj.type  = 'subj';
            obj.runs = RunClass().empty;
            if nargin==1
                if isa(varargin{1}, 'SubjClass')
                    obj.Copy(varargin{1});
                    return;
                elseif isa(varargin{1}, 'FileClass')
                    [~, obj.name] = varargin{1}.ExtractNames();
                else
                    obj.name = varargin{1};
                end
            elseif nargin==3
                if ~isa(varargin{1}, 'FileClass')
                    [~, obj.name] = varargin{1}.ExtractNames();
                else
                    obj.name = varargin{1};
                end
                obj.iGroup = varargin{2};
                obj.iSubj = varargin{3};
            else
                return;
            end
        end
        
        
        % ----------------------------------------------------------------------------------
        % Copy processing params (procInut and procResult) from
        % S to obj if obj and S are equivalent nodes
        % ----------------------------------------------------------------------------------
        function Copy(obj, S, conditional)
            if nargin==3 && strcmp(conditional, 'conditional')
                if strcmp(obj.name, S.name)
                    for i=1:length(obj.runs)
                        j = obj.existRun(i,S);
                        if (j>0)
                            obj.runs(i).Copy(S.runs(j), 'conditional');
                        end
                    end
                    if obj == S
                        obj.Copy@TreeNodeClass(S, 'conditional');
                    end
                end
            else
                for i=1:length(S.runs)
                    obj.runs(i) = RunClass(S.runs(i), 'spacesaver');
                end
                obj.Copy@TreeNodeClass(S);
            end
        end
        
        
        % ----------------------------------------------------------------------------------
        % Check whether run R exists in this subject and return
        % its index if it does exist. Else return 0.
        % ----------------------------------------------------------------------------------
        function j = existRun(obj, k, S)
            j=0;
            for i=1:length(S.runs)
                [~,rname1] = fileparts(obj.runs(k).name);
                [~,rname2] = fileparts(S.runs(i).name);
                if strcmp(rname1,rname2)
                    j=i;
                    break;
                end
            end
        end
        
        
        % ----------------------------------------------------------------------------------
        % Subjects obj1 and obj2 are considered equivalent if their names
        % are equivalent and their sets of runs are equivalent.
        % ----------------------------------------------------------------------------------
        function B = equivalent(obj1, obj2)
            B=1;
            if ~strcmp(obj1.name, obj2.name)
                B=0;
                return;
            end
            for i=1:length(obj1.runs)
                j = existRun(obj1, i, obj2);
                if j==0
                    B=0;
                    return;
                end
            end
            for i=1:length(obj2.runs)
                j = existRun(obj2, i, obj1);
                if j==0
                    B=0;
                    return;
                end
            end
        end
        
        
        % ----------------------------------------------------------------------------------
        function Add(obj, run)
            % Add run to this subject
            jj=0;
            for ii=1:length(obj.runs)
                if strcmp(obj.runs(ii).GetName, run.GetName())
                    jj=ii;
                    break;
                end
            end
            if jj==0
                jj = length(obj.runs)+1;
                run.SetIndexID(obj.iGroup, obj.iSubj, jj);
                obj.runs(jj) = run;
                fprintf('     Added run %s to subject %s.\n', obj.runs(jj).GetFileName, obj.GetName);
            end
        end
        
        
        
        % ----------------------------------------------------------------------------------
        function list = DepthFirstTraversalList(obj)
            list{1} = obj;
            for ii=1:length(obj.runs)
                list{ii+1,1} = obj.runs(ii);
            end
        end
        
        
        
        % ----------------------------------------------------------------------------------
        % Deletes derived data in procResult
        % ----------------------------------------------------------------------------------
        function Reset(obj)
            obj.procStream.output = ProcResultClass();
            for jj=1:length(obj.runs)
                obj.runs(jj).Reset();
            end
        end
        
        
        % ----------------------------------------------------------------------------------
        function Calc(obj, options)
            if ~exist('options','var') || isempty(options)
                options = 'overwrite';
            end
            
            if strcmpi(options, 'overwrite')
                % Recalculating result means deleting old results, if
                % option == 'overwrite'
                obj.procStream.output.Flush();
            end
                        
            if obj.DEBUG
                fprintf('Calculating processing stream for group %d, subject %d\n', obj.iGroup, obj.iSubj)
            end
            
            % Calculate all runs in this session
            r = obj.runs;
            nRun = length(r);
            nDataBlks = r(1).GetDataBlocksNum();
            tHRF_common = cell(nDataBlks,1);
            for iRun = 1:nRun
                r(iRun).Calc();
                
                % Find smallest tHRF among the runs. We should make this the common one.
                for iBlk = 1:nDataBlks
	                if isempty(tHRF_common{iBlk})
                        tHRF_common{iBlk} = r(iRun).procStream.output.GetTHRF(iBlk);
                    elseif length(r(iRun).procStream.output.GetTHRF(iBlk)) < length(tHRF_common{iBlk})
                        tHRF_common{iBlk} = r(iRun).procStream.output.GetTHRF(iBlk);
                    end
                end
            end
            
            % Set common tHRF: make sure size of tHRF, dcAvg and dcAvg is same for
            % all runs. Use smallest tHRF as the common one.
            for iRun = 1:nRun
                for iBlk = 1:length(tHRF_common)
                    r(iRun).procStream.output.SettHRFCommon(tHRF_common{iBlk}, r(iRun).name, r(iRun).type, iBlk);
                end
            end            
            
            % Instantiate all the variables that might be needed by
            % procStream.Calc() to calculate proc stream for this subject
            vars = [];
            for iRun = 1:nRun
                vars.dcRuns{iRun}        = r(iRun).procStream.output.GetVar('dc');
                vars.dodRuns{iRun}       = r(iRun).procStream.output.GetVar('dod');
                vars.dodAvgRuns{iRun}    = r(iRun).procStream.output.GetVar('dodAvg');
                vars.dodAvgStdRuns{iRun} = r(iRun).procStream.output.GetVar('dodAvgStd');
                vars.dodSum2Runs{iRun}   = r(iRun).procStream.output.GetVar('dodSum2');
                vars.dcAvgRuns{iRun}     = r(iRun).procStream.output.GetVar('dcAvg');
                vars.dcAvgStdRuns{iRun}  = r(iRun).procStream.output.GetVar('dcAvgStd');
                vars.dcSum2Runs{iRun}    = r(iRun).procStream.output.GetVar('dcSum2');
                vars.tHRFRuns{iRun}      = r(iRun).procStream.output.GetTHRF();
                vars.nTrialsRuns{iRun}   = r(iRun).procStream.output.GetVar('nTrials');
                vars.mlActRuns{iRun}     = r(iRun).procStream.output.GetVar('mlActAuto');
                vars.SDRuns{iRun}        = r(iRun).GetMeasList();
                vars.stimRuns{iRun}      = r(iRun).GetVar('stim');
            end
            
            % Make variables in this subject available to processing stream input
            obj.procStream.input.LoadVars(vars);

            % Calculate processing stream
            obj.procStream.Calc();

            if obj.DEBUG
                fprintf('Completed processing stream for group %d, subject %d\n', obj.iGroup, obj.iSubj);
                fprintf('\n');
            end
            
            % Update call application GUI using it's generic Update function 
            if ~isempty(obj.updateParentGui)
                obj.updateParentGui('DataTreeClass', [obj.iGroup, obj.iSubj, obj.iRun]);
            end
            pause(.5);
        end
                
        
        % ----------------------------------------------------------------------------------
        function CalcRunLevelTimeCourse(obj)
            r = obj.runs;
            nRun = length(r);
            for iRun = 1:nRun
                r(iRun).CalcTimeCourses();
            end
        end
        
        

        % ----------------------------------------------------------------------------------
        function Print(obj, indent)
            if ~exist('indent', 'var')
                indent = 2;
            end
            if ~exist('indent', 'var')
                indent = 2;
            end
            fprintf('%sSubject %d:\n', blanks(indent), obj.iSubj);
            fprintf('%sCondNames: %s\n', blanks(indent+4), cell2str(obj.CondNames));
            obj.procStream.input.Print(indent+4);
            obj.procStream.output.Print(indent+4);
            for ii=1:length(obj.runs)
                obj.runs(ii).Print(indent+4);
            end
        end
        

        % ----------------------------------------------------------------------------------
        function b = IsEmpty(obj)
            b = true;
            if isempty(obj)
                return;
            end
            for ii=1:length(obj.runs)
                if ~obj.runs(ii).IsEmpty()
                    b = false;
                    break;
                end
            end
        end


    end
    
    
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Public Set/Get methods
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    methods
        
        % ----------------------------------------------------------------------------------
        function SetSDG(obj)
            obj.SD = obj.runs(1).GetSDG();
        end
        
        
        % ----------------------------------------------------------------------------------
        function SD = GetSDG(obj)
            SD = obj.runs(1).GetSDG();
        end
        
        
        % ----------------------------------------------------------------------------------
        function srcpos = GetSrcPos(obj)
            srcpos = obj.runs(1).GetSrcPos();
        end
        
        
        % ----------------------------------------------------------------------------------
        function detpos = GetDetPos(obj)
            detpos = obj.runs(1).GetDetPos();
        end
        
        
        % ----------------------------------------------------------------------------------
        function bbox = GetSdgBbox(obj)
            bbox = obj.runs(1).GetSdgBbox();
        end
        
        
        % ----------------------------------------------------------------------------------
        function ch = GetMeasList(obj, iBlk)
            if ~exist('iBlk','var') || isempty(iBlk)
                iBlk=1;
            end
            ch = obj.runs(1).GetMeasList(iBlk);
        end
                
        
        % ----------------------------------------------------------------------------------
        function wls = GetWls(obj)
            wls = obj.runs(1).GetWls();
        end
        
        
        % ----------------------------------------------------------------------------------
        function [iDataBlks, iCh] = GetDataBlocksIdxs(obj, iCh)
            if nargin<2
                iCh = [];
            end
            [iDataBlks, iCh] = obj.runs(1).GetDataBlocksIdxs(iCh);
        end
        
        
        % ----------------------------------------------------------------------------------
        function n = GetDataBlocksNum(obj)
            n = obj.runs(1).GetDataBlocksNum();
        end
       
        
        % ----------------------------------------------------------------------------------
        function SetConditions(obj, CondNames)
            if nargin==1
                CondNames = {};
                for ii=1:length(obj.runs)
                    obj.runs(ii).SetConditions();
                    CondNames = [CondNames, obj.runs(ii).GetConditions()];
                end
            elseif nargin==2
                for ii=1:length(obj.runs)
                    obj.runs(ii).SetConditions(CondNames);
                end                
            end
            obj.CondNames = unique(CondNames);
        end
        
        
        % ----------------------------------------------------------------------------------
        function CondNames = GetConditionsActive(obj)
            CondNames = obj.CondNames;
            for ii=1:length(obj.runs)
                CondNamesRun = obj.runs(ii).GetConditionsActive();
                for jj=1:length(CondNames)
                    k = find(strcmp(['-- ', CondNames{jj}], CondNamesRun));
                    if ~isempty(k)
                        CondNames{jj} = ['-- ', CondNames{jj}];
                    end
                end
            end
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
            newname = obj.ErrCheckNewCondName(newname);
            if obj.err ~= 0
                return;
            end
            for ii=1:length(obj.runs)
                obj.runs(ii).RenameCondition(oldname, newname);
            end
        end
        
    end
        
end
