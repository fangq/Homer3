classdef RunClass < TreeNodeClass
    
    properties % (Access = private)
        acquired;
    end
    
    methods
                
        % ----------------------------------------------------------------------------------
        function obj = RunClass(varargin)
            %
            % Syntax:
            %   obj = RunClass()
            %   obj = RunClass(filename);
            %   obj = RunClass(filename, iGroup, iSubj, iRun);
            %   obj = RunClass(run);
            %
            % Example 1:
            %   run1     = RunClass('./s1/neuro_run01.nirs',1,1,1);
            %   run1copy = RunClass(run1);
            %
            obj@TreeNodeClass(varargin);
            obj.type  = 'run';
            if nargin==0
                obj.name  = '';
                return;
            end    
                        
            if isa(varargin{1}, 'RunClass')
                obj.Copy(varargin{1});
                return;
            elseif isa(varargin{1}, 'FileClass')
                [~, ~, obj.name] = varargin{1}.ExtractNames();
            elseif ischar(varargin{1}) && strcmp(varargin{1},'copy')
                return;
            elseif ischar(varargin{1}) 
                obj.name = varargin{1};
            end
            if nargin==4
                obj.iGroup = varargin{2};
                obj.iSubj  = varargin{3};
                obj.iRun   = varargin{4};
            end
            
            obj.Load();
            if obj.acquired.IsEmpty()
                obj = RunClass.empty();
                return;
            end
            obj.procStream = ProcStreamClass(obj.acquired);

            if isa(varargin{1}, 'FileClass')
                varargin{1}.Loaded();
            end
        end

        
            
        % ----------------------------------------------------------------------------------
        function Load(obj)
            if isempty(obj)
                return;
            end
            if obj.IsNirs()
                obj.acquired = NirsClass(obj.name);
            else
                obj.acquired = SnirfClass(obj.name);
            end            
            if obj.acquired.IsEmpty()
                fprintf('     **** Warning: %s failed to load.\n', obj.name);
            else
                %fprintf('    Loaded file %s to run.\n', obj.name);                
            end
        end
        
                
        
        % ----------------------------------------------------------------------------------
        % Deletes derived data in procResult
        % ----------------------------------------------------------------------------------
        function Reset(obj)
            obj.procStream.output = ProcResultClass();
        end
        
        
        
        % ----------------------------------------------------------------------------------
        % Copy processing params (procInut and procResult) from
        % N2 to N1 if N1 and N2 are same nodes
        % ----------------------------------------------------------------------------------
        function Copy(obj, R, conditional)
            if nargin==3 && strcmp(conditional, 'conditional')
                if obj == R
                    obj.Copy@TreeNodeClass(R, 'conditional');
                end
            else
                obj.Copy@TreeNodeClass(R);
            end
        end
            
        % ----------------------------------------------------------------------------------
        % Subjects obj1 and obj2 are considered equivalent if their names
        % are equivalent and their sets of runs are equivalent.
        % ----------------------------------------------------------------------------------
        function B = equivalent(obj1, obj2)
            B=1;
            [p1,n1] = fileparts(obj1.name);
            [p2,n2] = fileparts(obj2.name);
            if ~strcmp([p1,'/',n1],[p2,'/',n2])
                B=0;
                return;
            end
        end
        

        % ----------------------------------------------------------------------------------
        function b = IsEmpty(obj)
            b = true;
            if isempty(obj)
                return;
            end
            if obj.acquired.IsEmpty()
                return;
            end
            b = false;
        end
               
    end
    
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % 
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    methods
            
        % ----------------------------------------------------------------------------------
        function b = IsNirs(obj)
            b = false;
            [~,~,ext] = fileparts(obj.name);
            if strcmp(ext,'.nirs')
                b = true;
            end
        end
        
        
        % ----------------------------------------------------------------------------------
        function varval = GetVar(obj, varname)
            varval = [];
            if isproperty(obj, varname)
                varval = eval( sprintf('obj.%s', varname) );
            end
            if isempty(varval)
                varval = obj.procStream.GetVar(varname);
            end
            if isempty(varval)
                varval = obj.acquired.GetVar(varname);
            end
        end
        
        
        % ----------------------------------------------------------------------------------
        function Calc(obj, options)
            if ~exist('options','var') || isempty(options)
                options = 'overwrite';
            end
            
            % Update call application GUI using it's generic Update function 
            if ~isempty(obj.updateParentGui)
                obj.updateParentGui('DataTreeClass', [obj.iGroup, obj.iSubj, obj.iRun]);
            end
            
            if strcmpi(options, 'overwrite')
                % Recalculating result means deleting old results, if
                % option == 'overwrite'
                obj.procStream.output.Flush();
            end
            
            if obj.DEBUG
                fprintf('Calculating processing stream for group %d, subject %d, run %d\n', obj.iGroup, obj.iSubj, obj.iRun);
            end
            
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % Find all variables needed by proc stream, find them in this 
            % runs, and load them to proc stream input
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            
            % a) Find all variables needed by proc stream
            args = obj.procStream.GetInputArgs();

            % b) Find these variables in this run
            vars = [];
            for ii=1:length(args)
                eval( sprintf('vars.%s = obj.GetVar(args{ii});', args{ii}) );
            end
            
            % c) Load the needed variables to proc stream input
            obj.procStream.input.LoadVars(vars);

            % Calculate processing stream
            obj.procStream.Calc();

            if obj.DEBUG
                fprintf('Completed processing stream for group %d, subject %d, run %d\n', obj.iGroup, obj.iSubj, obj.iRun);
                fprintf('\n')
            end
            
        end


        
        % ----------------------------------------------------------------------------------
        function CalcTimeCourses(obj)
            if obj.procStream.HaveTimeCourseOutput()
                return;
            end
            obj.procStream.FcallsIdxsTimeCourses();
            obj.Calc('keepexisting');
            obj.procStream.FcallsIdxsReset();
        end
        
        
        
        % ----------------------------------------------------------------------------------
        function Print(obj, indent)
            if ~exist('indent', 'var')
                indent = 4;
            end
            fprintf('%sRun %d:\n', blanks(indent), obj.iRun);
            fprintf('%sCondNames: %s\n', blanks(indent+4), cell2str(obj.CondNames));
            obj.procStream.input.Print(indent+4);
            obj.procStream.output.Print(indent+4);            
        end
        
    end    % Public methods
    
    
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Pubic Set/Get methods for acquired data 
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    methods
            
        % ----------------------------------------------------------------------------------
        function t = GetTime(obj, iBlk)
            if nargin==1
                iBlk=1;
            end
            t = obj.acquired.GetTime(iBlk);
        end
        
        
        % ----------------------------------------------------------------------------------
        function t = GetTimeCombined(obj)
            t = obj.acquired.GetTimeCombined();
        end
            
            
        % ----------------------------------------------------------------------------------
        function d = GetRawData(obj, iBlk)
            if nargin<2
                iBlk = 1;
            end
            d = obj.acquired.GetDataMatrix(iBlk);
        end
        
        
        % ----------------------------------------------------------------------------------
        function d = GetDataMatrix(obj, iBlk)
            if nargin<2
                iBlk = 1;
            end
            d = obj.acquired.GetDataMatrix(iBlk);
        end
        
        
        % ----------------------------------------------------------------------------------
        function [iDataBlks, iCh] = GetDataBlocksIdxs(obj, iCh)
            if nargin<2
                iCh = [];
            end
            [iDataBlks, iCh] = obj.acquired.GetDataBlocksIdxs(iCh);
        end
        
        
        % ----------------------------------------------------------------------------------
        function n = GetDataBlocksNum(obj)
            n = obj.acquired.GetDataBlocksNum();
        end
       
        
        % ----------------------------------------------------------------------------------
        function SD = GetSDG(obj)
            SD.Lambda  = obj.acquired.GetWls();
            SD.SrcPos  = obj.acquired.GetSrcPos();
            SD.DetPos  = obj.acquired.GetDetPos();
        end
        
        
        
        % ----------------------------------------------------------------------------------
        function ch = GetMeasList(obj, iBlk)
            if ~exist('iBlk','var') || isempty(iBlk)
                iBlk=1;
            end
            ch                    = InitMeasLists();
            
            ch.MeasList        = obj.acquired.GetMeasList(iBlk);
            ch.MeasListActMan  = obj.procStream.GetMeasListActMan(iBlk);
            ch.MeasListActAuto = obj.procStream.GetMeasListActAuto(iBlk);
            ch.MeasListVis     = obj.procStream.GetMeasListVis(iBlk);
            
            if isempty(ch.MeasListActMan)
                ch.MeasListActMan  = ones(size(ch.MeasList,1),1);
            end
            if isempty(ch.MeasListActAuto)
                ch.MeasListActAuto = ones(size(ch.MeasList,1),1);
            end
            if isempty(ch.MeasListVis)
                ch.MeasListVis = ones(size(ch.MeasList,1),1);
            end
            ch.MeasListAct     = bitand(ch.MeasListActMan, ch.MeasListActMan);
        end

        
        % ----------------------------------------------------------------------------------
        function SetStims_MatInput(obj,s,t,CondNames)
            obj.procStream.SetStims_MatInput(s,t,CondNames);
        end
        
        
        % ----------------------------------------------------------------------------------
        function s = GetStims(obj, t)            
            % Proc stream output 
            s_inp = obj.procStream.input.GetStims(t);
            s_out = obj.procStream.output.GetStims(t);
            
            k_inp_all  = find(s_inp~=0);
            k_out_edit = find(s_out~=0 & s_out~=1);
            
            % Select only those output stims which exist in the input
            b = ismember(k_out_edit, k_inp_all);
            
            s = s_inp;
            s(k_out_edit(b)) = s_out(k_out_edit(b));
        end
        
        
        % ----------------------------------------------------------------------------------
        function SetConditions(obj, CondNames)
            if nargin==2
                obj.procStream.SetConditions(CondNames);
            end
            obj.CondNames = unique(obj.procStream.GetConditions());
        end
        
        
        % ----------------------------------------------------------------------------------
        function CondNames = GetConditions(obj)
            CondNames = obj.procStream.GetConditions();
        end
        
        
        % ----------------------------------------------------------------------------------
        function CondNames = GetConditionsActive(obj)
            CondNames = obj.CondNames;
            t = obj.GetTime();
            s = obj.GetStims(t);
            for ii=1:size(s,2)
                if ismember(abs(1), s(:,ii))
                    CondNames{ii} = ['-- ', CondNames{ii}];
                end
            end
        end
        
        
        % ----------------------------------------------------------------------------------
        function wls = GetWls(obj)
            wls = obj.acquired.GetWls();
        end
        
        
        % ----------------------------------------------------------------------------------
        function bbox = GetSdgBbox(obj)
            bbox = obj.acquired.GetSdgBbox();
        end
        
        
        % ----------------------------------------------------------------------------------
        function aux = GetAux(obj)
            aux = obj.acquired.GetAux();            
        end
        
        
        % ----------------------------------------------------------------------------------
        function tIncAuto = GetTincAuto(obj, iBlk)
            if nargin<2
                iBlk = 1;
            end
            tIncAuto = obj.procStream.output.GetTincAuto(iBlk);
        end
        
        
        % ----------------------------------------------------------------------------------
        function tIncMan = GetTincMan(obj, iBlk)
            if nargin<2
                iBlk = 1;
            end
            tIncMan = obj.procStream.input.GetTincMan(iBlk);
        end
        
        
    end        % Public Set/Get methods
    
    
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % All other public methods for acquired data
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    methods
        
        
        % ----------------------------------------------------------------------------------
        function AddStims(obj, tPts, condition)
            if isempty(tPts)
                return;
            end
            if isempty(condition)
                return;
            end
            obj.procStream.AddStims(tPts, condition);
        end

        
        % ----------------------------------------------------------------------------------
        function DeleteStims(obj, tPts, condition)
            if ~exist('tPts','var') || isempty(tPts)
                return;
            end
            if ~exist('condition','var')
                condition = '';
            end
            obj.procStream.DeleteStims(tPts, condition);
        end
        
        
        % ----------------------------------------------------------------------------------
        function MoveStims(obj, tPts, condition)
            if ~exist('tPts','var') || isempty(tPts)
                return;
            end
            if ~exist('condition','var')
                condition = '';
            end
            obj.procStream.MoveStims(tPts, condition);
        end
        
        
        % ----------------------------------------------------------------------------------
        function [tpts, duration, vals] = GetStimData(obj, icond)
            tpts     = obj.GetStimTpts(icond);
            duration = obj.GetStimDuration(icond);
            vals     = obj.GetStimValues(icond);
        end
        
    
        % ----------------------------------------------------------------------------------
        function SetStimTpts(obj, icond, tpts)
            obj.procStream.SetStimTpts(icond, tpts);
        end
        
    
        % ----------------------------------------------------------------------------------
        function tpts = GetStimTpts(obj, icond)
            if ~exist('icond','var')
                icond=1;
            end
            tpts = obj.procStream.GetStimTpts(icond);
        end
        
        
        % ----------------------------------------------------------------------------------
        function SetStimDuration(obj, icond, duration)
            obj.procStream.SetStimDuration(icond, duration);
        end
        
    
        % ----------------------------------------------------------------------------------
        function duration = GetStimDuration(obj, icond)
            if ~exist('icond','var')
                icond=1;
            end
            duration = obj.procStream.GetStimDuration(icond);
        end
        
        
        % ----------------------------------------------------------------------------------
        function SetStimValues(obj, icond, vals)
            obj.procStream.SetStimValues(icond, vals);
        end
        
    
        % ----------------------------------------------------------------------------------
        function vals = GetStimValues(obj, icond)
            if ~exist('icond','var')
                icond=1;
            end
            vals = obj.procStream.GetStimValues(icond);
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
            obj.procStream.RenameCondition(oldname, newname);
        end
        
        
        % ----------------------------------------------------------------------------------
        function vals = GetStimValSettings(obj)
            vals = obj.procStream.input.GetStimValSettings();
        end        
        
        
    end

end
