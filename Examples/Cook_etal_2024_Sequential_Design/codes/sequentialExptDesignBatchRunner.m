function [TestCases,finalExperimentDesign] = sequentialExptDesignBatchRunner(iModel,iDesign,rngSeed, makePlots, testing, plotTimes)
arguments
    iModel
    iDesign
    rngSeed
    makePlots = false
    testing  = false
    plotTimes = []
end

nRounds = 8;
initialExperiment = [];
nFIMsamples = 10;

switch iDesign
    case 1
        design = 'fimopt';
    case 2
        design = 'random';
end
incrementAdd = 10;
switch iModel
    case 'Poisson' % Poisson
        %% Poisson Model With Chainging Input
        truePars = {'kr',10;'gr',0.3;'kD',5};
        inputLibrary = {{'IDex','1'},{'IDex','2'},{'IDex','3'},{'IDex','4'},{'IDex','5'},{'IDex','6'},...
            {'IDex','7'},{'IDex','8'},{'IDex','9'},{'IDex','10'}};
        model = 'poisson';
        numCellsPerExperiment = 60;
        initialParGuess = ones(1,3);
        datType = 'simulated';
        nInputs = length(inputLibrary);
        nT = 21;
        initialExperiment = zeros(nInputs,nT);
        initialExperiment(1,[1,7,14,21]) = round(numCellsPerExperiment/4);

        parset = [1:size(truePars,1)];
        iModel = 1;

    case 'Burst' % Uncertain Burst
        %% Burst Model With Unknown Control Mechanism
        truePars = ({'kon',0.1;'koff',0.2;'kr',10;'gr',0.3;'M',4;'alph',1e-4});
        inputLibrary = {{'IDex','1'},{'IDex','2'},{'IDex','3'},{'IDex','4'},{'IDex','5'},{'IDex','6'},...
            {'IDex','7'},{'IDex','8'},{'IDex','9'},{'IDex','10'}};
        model = 'burst';
        numCellsPerExperiment = 300;
        initialParGuess = 10.^[-1 -1 1 -1 1 0];
        % initialParGuess = [truePars{:,2}];
        datType = 'simulated';
        nInputs = length(inputLibrary);
        nT = 31;
        initialExperiment = zeros(nInputs,nT);
        initialExperiment([2,6,10],[1,6,11,16]) = 50;

        parset = [1:5];
        iModel = 5;
    case 'GR' % GR Reduced
         %% GR Model (Real Data)
        nRounds = 8;
        truePars = [];

        inputLibrary = {{'IDex','1'},{'IDex','10'},{'IDex','100'}};
        initialParGuess = 10.^[-2 1 -2 -2 -2 1];
        model = 'gr';
        numCellsPerExperiment = 300;
        datType = 'real';

        incrementAdd = 50;

        initialExperiment = zeros(3,6);
        initialExperiment(3,[1,3,6]) = 150;
        initialExperiment(1,[1,3,6]) = 150;

        parset = [2,5,6];
        iModel = 8;
end

jobID = 1000*iModel+100*iDesign+rngSeed;

TestCases = struct('model',{model},...
    'expDesign',{design},...
    'numCellsPerExperiment',{numCellsPerExperiment},...
    'figureSet',{iModel},...
    'incrementAdd',{incrementAdd},...
    'truePars',{truePars},...
    'saveFileNamePrefix',{['results/mod_',model,'_',num2str(iDesign),design,'_',num2str(rngSeed),'seed']}, ...
    'initialParameterGuess',{initialParGuess},...
    'inputLibrary',{inputLibrary},...
    'dataType',{datType});

%% Run Sequential Design Simulations
TestCases.saveName = iterativeExperimentRunnerMultiConditions(TestCases.model,...
        TestCases.dataType,...
        TestCases.expDesign,nRounds,rngSeed,jobID,...
        TestCases.incrementAdd,...
        TestCases.numCellsPerExperiment,...
        initialExperiment,nFIMsamples,...
        TestCases.truePars,...
        TestCases.saveFileNamePrefix,...
        TestCases.initialParameterGuess,...
        TestCases.inputLibrary,...
        testing);

if ~makePlots
    return
end


%% Load results and make plots
load(TestCases.saveName)
nRounds = 0;
while nRounds<length(covLogMH)&&~isempty(covLogMH{nRounds+1})
    nRounds=nRounds+1;
end

for iRound = 1:nRounds
    TestCases.detCov(iRound) = det(covLogMH{iRound}(parset,parset));
    TestCases.pars(iRound,:) = parametersFound{iRound};

    TestCases.FIMpredNextExpt = FIMpredNextExpt;
    TestCases.MHResultsSaved = MHResultsSaved;

    [TestCases.detFIMInv_Pred(iRound),...
        TestCases.stdDetFIMInv_Pred(iRound),...
        TestCases.minDetFIMInv_Pred(iRound),...
        TestCases.maxDetFIMInv_Pred(iRound)] = ...
        predictCov(FIMpredNextExpt{iRound},parset);
    
    [TestCases.detFIMInv_Post(iRound),...
        TestCases.stdDetFIMInv_Post(iRound),...
        TestCases.minDetFIMInv_Post(iRound),...
        TestCases.maxDetFIMInv_Post(iRound)] = ...
        predictCov(FIMcurrentExptSaved{iRound},parset);

    TestCases.detFIMTrueInv(iRound) = predictCov(FIMcurrentExptTrueSaved{iRound},parset);
    
    TestCases.FIMTrue(iRound) = FIMcurrentExptTrueSaved{iRound};

    TestCases.measurements = exptDesigns;
end

cols = ['rkbg'];
%% Make figures of det(COV) vs experiment round
for j = 1:3
    fset = TestCases.figureSet;
    f = figure(fset*100+1);
    set(f,'Name',[TestCases.model,' performance'])
    switch j
        case 1
            plot(1:nRounds,TestCases.detCov,'linewidth',2,'Color',cols(iDesign)); hold on;
        case 2
            plot(2:nRounds,TestCases.detFIMInv_Pred(1:end-1),'--','linewidth',2,'Color',cols(iDesign)); hold on;
            % errorbar(2:nRounds,TestCases.detFIMInv_Pred(1:end-1),...
            %     TestCases.stdDetFIMInv_Pred(1:end-1),...
            %     '--','linewidth',2,'Color',cols(iDesign)); hold on;
            % errorbar(2:nRounds,TestCases.detFIMInv_Pred(1:end-1),...
            %     TestCases.detFIMInv_Pred(1:end-1) - TestCases.minDetFIMInv_Pred(1:end-1),...
            %     TestCases.maxDetFIMInv_Pred(1:end-1) - TestCases.detFIMInv_Pred(1:end-1),...
            %     '--','linewidth',2,'Color',cols(iDesign)); hold on;
        case 3
            if strcmp(datType,'simulated')
                plot(1:nRounds,TestCases.detFIMTrueInv,'s','linewidth',2,'MarkerSize',16,'Color',cols(iDesign),'MarkerFaceColor',cols(iDesign)); hold on;
            else
                plot(1:nRounds,TestCases.detFIMInv_Post,'s','linewidth',2,'MarkerSize',16,'Color',cols(iDesign),'MarkerFaceColor',cols(iDesign)); hold on;
            end          
    end
    set(gca,"FontSize",16,'yscale','log')
    legend(TestCases([TestCases.figureSet]==fset).expDesign)

end
xlabel('Experiment round');

%% Make Figures for MH Results and FIM Analyses
fset = TestCases.figureSet;
for iExpt = plotTimes
    f = figure(fset*100+10+iDesign*length(FIMpredNextExpt)+iExpt); 
    set(f,'Name',[TestCases.model,', ',TestCases.expDesign,', round ',num2str(iExpt)])
    if iExpt==1
        SSIT.plotMHResultsStatic([],...
            TestCases.MHResultsSaved{iExpt}, ...
            TestCases.FIMTrue{iExpt},...
            'log','log10',f,true);
    else
        SSIT.plotMHResultsStatic([],...
            TestCases.MHResultsSaved{iExpt}, ...
            TestCases.FIMpredNextExpt{iExpt-1},...
            'log','log10',f,true);
    end
    % hold on;
    % npars = size(TestCases.truePars,1);
    % for iy = 1:npars-1
    %     for ix = iy+1:npars
    %         subplot(npars-1,npars-1,ix-1+(iy-1)*(npars-1))
    %         ylims = get(gca,'YLim')+[-1,1];
    %         xlims = get(gca,'XLim')+[-1,1];
    %         plot(log10(TestCases.truePars{ix,2})*[1,1],ylims,'k--','LineWidth',2)
    %         plot(xlims,log10(TestCases.truePars{iy,2})*[1,1],'k--','LineWidth',2)
    %     end
    % end
end

%% Make figure of parameter convergence
linspecs = ['--';'-.';'--';'-.'];
cols = ['rbrb'];
fset = TestCases.figureSet;
f = figure(fset*100+3);

set(f,'Name',['Parameters, ' TestCases.model])
semilogy(TestCases.pars,linspecs(iDesign,:),'LineWidth',3,'Color',cols(iDesign));hold on;
for jpar = 1:size(TestCases.truePars,1)
    plot([1,size(TestCases.pars,1)],TestCases.truePars{jpar,2}*[1,1],'k--')
end


%% Make figures of final experiment designs
% fset = TestCases.figureSet;
% f = figure(fset*100+2);
% set(f,'Name',[TestCases.model,' experiment design, ',TestCases.expDesign])
finalExperimentDesign = initialExperiment;
if iModel==8
    for j = 1:min(nRounds-1,5)
        finalExperimentDesign = finalExperimentDesign + TestCases.measurements{j};
    end

else

    for j = 1:nRounds-1
        finalExperimentDesign = finalExperimentDesign + TestCases.measurements{j};
    end
end
% bar(finalExperimentDesign'); hold on;
% set(gca,"FontSize",16)
% xlabel('Measurement Times')
% ylabel('Number of Cells Measured')
end

function [predictedDetCov,stdvDetCov,minDetCov,maxDetCov] = predictCov(fimSet,parSet)
arguments
    fimSet
    parSet = [1:length(fimSet{1})];
end
detCovPreds = zeros(1,length(fimSet));
for i = 1:length(fimSet)
    covEst = fimSet{i}^(-1);
    detCovPreds(i) = det(covEst(parSet,parSet));
end
predictedDetCov = mean(detCovPreds);
stdvDetCov = std(detCovPreds);
minDetCov = min(detCovPreds);
maxDetCov = max(detCovPreds);
end

% plot(2:nRounds,detFIMTrueInv_FIM,'k',2:nRounds,detFIMTrueInv_FIM,'--k',2:nRounds,detFIMTrueInv_FIM,'-.k','linewidth',2)
% legend('|COV|','|FIM^-1|','|FIM^-1| True')