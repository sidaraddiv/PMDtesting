/**
* @author Prashant Wayal
* @date 15/09/2016
* @description Class used to trigger the jenkins job from salesforce
*/

public with sharing class DeployController{
    //variable
    public Boolean jobStarted{ get; set; }
    public Boolean showReleaseWin{ get; set; }
    public String jobType{ get; set; }
    public Boolean refreshContinue{ get; set; }
    public Release__c releaseObj{ get; set; }
    public List<SelectOption> orgList{ get; set; } //Get source and target org list from custom settings
    public String selectedOrg{ get; set; } //Selected source and target org for deployment
    public String selectedChecklist{ get; set; } //Selected checklist for deployment
    public Map<String, Jenkins_Jobs__c> jobsSettingsMap{ get; set; } //Map to hold values for Jenkins_Jobs__c records with key as name
    public List<SelectOption> checklistList{ get; set; } //Available checklists for selected release
    public List<PipelineDetails> pipelineList{ get; set; } //List of pipeline
    public Transient String chartValues{ get; set; }
    public List<Manual_steps_tracker__c> stepTrackerList{ get; set; }
    public boolean showStepTrackers{ get; set; }
    public boolean showStepTrackers1{ get; set; }
    public boolean ApprovalStep{ get; set; }   
    public Boolean isError{ get; set; }
    public String errorMessage{ get; set; }
    public Jenkins_Jobs__c jenkinsJobs{ get; set; }
    public RM_Configuration__c jenkinsJob{ get; set; }
    public List<SelectOption> recTypeList{ get; set; }
    public String selectedRelease{ get; set; }
    public List<SelectOption> releaseList{ get; set; }
    public Map<String, Release__c> releaseMap{ get; set; }
    public Boolean displayRelease{ get; set; }
    Map<String, Release_Checklist__c> checklistMap{ get; set; }
    public Boolean manualStepsCompleted{ get; set; }
    public Boolean createDeployment{ get; set; }
    public RM_Configuration__c config{ get; set; }
    public Transient String logBody{ get; set; }
    public Boolean showLog{ get; set; }
    public Transient String logStageName{ get; set; }
    public String contentType{ get; set; }
    public Transient Attachment currentLog{ get; set; }
    public Transient String chartData{ get; set; }
    public Transient List<Attachment> docList{ get; set; }
    public Transient List<StageLogDocuments> newdocList{ get; set; }
    public Map<String, String> fileTypeMap{ get; set; }
    public Map<String, Map<String, List<String>>> artifactMap{ get; set; }
    public Integer artifactSize{ get; set; }
    public static RM_Configuration__c jenkinsUser{ get; set; }
    public Transient String summary{ get; set; }
    public Map<String, RM_Configuration__c> jobsMap{ get; set; }
    public Release__c rel{ get; set; }
    public string approvalErrMsg{get;set;}
    
    public Manual_steps_tracker__c manualStep{ get; set; }
    public Boolean fieldRequired{ get; set; }
    public String recTypeId{ get; set; }
    public List<Release_Tracker__c> relTrack{get; set;}
    public Boolean buildTriggered{ get; set; }
    
    public Boolean jobCompleted{ get; set; }
    public Boolean viewComponents{ get; set; }
    public JenkinsJobDetails.ArtifactDetails deploymentComponentData{ get; set; }
    
     @TestVisible 
    list<Release__c> releaseRecList = new list<Release__c> ();

    static{
        List<RM_Configuration__c> configUsers = [select Jenkins_User_Name__c, Jenkins_Password__c, Jenkins_User_Active__c 
                                                 from RM_Configuration__c where Jenkins_User_Active__c = true 
                                                 AND RecordTypeId =: DeploymentControllerService.getRecordTypeIdByName('RM_Configuration__c', 'Jenkins Authentication')
                                                 AND SFDC_User__c =: UserInfo.getUserId() 
                                                 LIMIT 1 ];
        
        if(configUsers != null && !configUsers.isEmpty()){
            jenkinsUser = configUsers[0];
        }
        
    }
    
    public DeployController() {
        //initialize variables  
        jobStarted = jobCompleted = viewComponents = false;
        //showReleaseWin = false;
        refreshContinue = triggerJob = true;
        displayRelease = buildTriggered = false; 
        String docId = ApexPages.CurrentPage().getParameters().get('docId');
        jobType = 'd'; //ApexPages.CurrentPage().getParameters().get('jt');
        //String jobTypeValue = (jobType=='d')?'Deployment':'Validation';
        pipelineList = new List<PipelineDetails>();
        chartValues = logBody = contentType = '';
        showStepTrackers = showStepTrackers1 = showLog =ApprovalStep= false;
        manualStepsCompleted = false;
        isError = createDeployment = false;
        jenkinsJobs = new Jenkins_Jobs__c();
        jenkinsJob = new RM_Configuration__c();
        orgList = new List<SelectOption>();
        jobsSettingsMap = new Map<String, Jenkins_Jobs__c>();
        releaseList = new List<SelectOption>();
        releaseMap = new Map<String, Release__c>();
        checklistMap = new Map<String, Release_Checklist__c>();
        showReleaseWin = false;
        rel= new Release__c();        
        recTypeList = new List<SelectOption>();
        //dashboardList = new List<DashboardDetails>();
        //pipelineLogList = new List<Deployment_Stage__c>();
        currentLog = new Attachment();
        chartData = '';
        fileTypeMap = new Map<String, String>();
        fileTypeMap.put('html', 'html_60.png');
        fileTypeMap.put('log', 'txt_60.png');
        fileTypeMap.put('txt', 'txt_60.png');
        fileTypeMap.put('xls', 'excel_60.png');
        
        artifactMap = new Map<String, Map<String, List<String>>>();
        artifactSize = 0;
        selectedRelease = selectedOrg = '';
        
        fetchReleaseRecords();
        orgList.add(new SelectOption('', '-NONE-'));
        jobsMap = new Map<String, RM_Configuration__c>();
        jobsMap = AdminConsoleController.fetchConfigData();
        
        for(RM_Configuration__c configObj: jobsMap.values()){
            if(DeploymentControllerService.getRecordTypeIdByName('RM_Configuration__c', 'Jenkins Job') == configObj.recordTypeId){
                //if(configObj.Job_Type__c.equals(jobTypeValue))
                orgList.add(new SelectOption(configObj.Id, configObj.Job_Name__c));
            }
        }
            
        
        checklistList = new List<SelectOption>();
        checklistList.add(new SelectOption('', '-NONE-'));
    }
    
    public void fetchReleaseRecords(){
        releaseList.clear();
        releaseList.add(new SelectOption('', '-NONE-'));
        releaseRecList= [select Id,OwnerId,Owner.Name,User__c, Name,Approval_Status__c,RecordType.name,
                                    Deployment_Approval_Required__c,On_Demand_Validation_Needed__c, Release_Start_Date__c, 
                                    Release_Planned_End_Date__c, Production_Deploy_Approved__c,
                                    Prod_Validation_Complete__c from Release__c 
                                    where (Status__c = 'Yellow' OR Status__c = 'Red')];
        for(Release__c releaseObj: releaseRecList){
                                    
            releaseMap.put(releaseObj.Id, releaseObj);
            releaseList.add(new SelectOption(releaseObj.Id, releaseObj.Name));
        }
    }
    public PageReference selectRelease(){
        try{
            if(String.isBlank(selectedRelease)){
                isError = true;
                errorMessage = 'Please select release';
                displayRelease = false;
                checklistList.clear();
                return null;
            }
            else{
                if(releaseMap.containsKey(selectedRelease)){
                    releaseObj = releaseMap.get(selectedRelease);
                    displayRelease = true;
                    //Get checklist data
                    checklistList.clear();
                    for(Release_Checklist__c chk: [select Id, Name,Prod_Pre_Deploy_Complete__c, QA_Pre_Deploy_Complete__c,
                                                    UAT_Pre_Deploy_Complete__c from Release_Checklist__c where Release__c =: releaseObj.Id]){
                        checklistList.add(new SelectOption(chk.Id, chk.Name));
                        checklistMap.put(chk.Id, chk);
                        selectedChecklist = chk.Id;
                    }
                    relTrack = [Select Release__r.Id, Release__r.Name,SFEnvironment__r.Name,Code_Deployed__c,Validation_Completed__c From Release_Tracker__c WHERE Release__r.Id =: releaseObj.Id]; 
                }
                else{
                    releaseObj = new Release__c();
                    displayRelease = false;
                }
                selectedOrg = '';
                //generateDashboard(selectedChecklist, releaseObj.Id);
            }
        }
        catch(Exception e){
            isError = true;
            errorMessage = 'ERROR: '+e.getMessage();
        }
        return null;
    }
    
    public PageReference selectOrg(){
        try{
            if(String.isBlank(selectedRelease)){
                isError = true;
                errorMessage = 'Please select release';
                displayRelease = false;
                selectedOrg = '';
                return null;
            }
            if(String.isEmpty(selectedOrg)){
                isError = true;
                errorMessage = 'Please select environment';
                manualStepsCompleted = false;
                return null;
            }
            else{
                config = AdminConsoleController.readConfigData(jobsMap.values());
                System.debug('*** config *** '+config.Name + ' *** steps *** '+config.Manual_Steps_Required__c);
                manualStepsCompleted  = checkManualSteps(selectedOrg, selectedChecklist);
                fetchPipelineDetails(selectedOrg, selectedChecklist, releaseObj.Id);
            }
        }
        catch(Exception e){
            isError = true;
            errorMessage = 'ERROR: '+e.getMessage();
        }
        return null;
    }
    
    public Boolean checkManualSteps(String selectedOrg, String selectedChecklist){
        //jenkinsJobs = jobsSettingsMap.get(selectedOrg);
        jenkinsJob = jobsMap.get(selectedOrg);
        Release_Checklist__c chk = checklistMap.get(selectedChecklist);
        Boolean isCompleted = false;
        
        Integer countCompleted = [select count() from Manual_Steps_Environments__c 
                                  where SF_Environment__c =:jenkinsJob.Target_Environment__c
                                  AND Manual_Steps__r.Release_checklist__c =: chk.Id 
                                  AND Is_Completed__c = true];
                                  
        Integer countTotal = [select count() from Manual_Steps_Environments__c 
                                  where SF_Environment__c =:jenkinsJob.Target_Environment__c
                                  AND Manual_Steps__r.Release_checklist__c =: chk.Id
                                  ];
        if(countTotal == countCompleted){
            isCompleted = true;
        }
        
        return isCompleted;
    }
    
    public PageReference selectChecklist(){
        if(String.isBlank(selectedChecklist)){
            isError = true;
            errorMessage = 'Please select checklist';
            manualStepsCompleted = false;
            return null;
        }
        else{
            Release_Checklist__c chk = checklistMap.get(selectedChecklist);
            if(chk != null){
                manualStepsCompleted = chk.Prod_Pre_Deploy_Complete__c && chk.QA_Pre_Deploy_Complete__c && chk.UAT_Pre_Deploy_Complete__c;
            }
            else{
                manualStepsCompleted = false;
            }
        }
        return null;
    }
    
    public void updateStageStatus(String selectedOrg, String checklistId, String releaseId){
        if(String.isBlank(selectedOrg)){
            isError = true;
            errorMessage = 'Please select environment';
        }
        else if(String.isBlank(checklistId)){
            isError = true;
            errorMessage = 'Please select checklist';
        }
        else if(String.isBlank(releaseId)){
            isError = true;
            errorMessage = 'Release Id not defined, please check your URL';
        }
        else if(jenkinsUser == null || (jenkinsUser != null && !jenkinsUser.Jenkins_User_Active__c)){
            isError = true;
            errorMessage = 'Jenkins user not found for you. Please add Jenkins user from Settigs tab';
        }
        else{
            try{
                isError = false;
                jenkinsJobs = jobsSettingsMap.get(selectedOrg);
                jenkinsJob = jobsMap.get(selectedOrg);
                String sourceOrg = jenkinsJob.Source_Org__c;
                String targetOrg = jenkinsJob.Target_Org__c;
                pipelineList.clear();
                Integer cntSuccess = 0;
                Integer cntFailure = 0;
                Integer cntInProgress = 0;
                Integer cnt = 0;
                List<Deployment_Stage__c> stagesList = new List<Deployment_Stage__c>();
                Integer prevOrder = 0;
                String prevStatus = '';
                List<Deployment__c> depList = new List<Deployment__c>();
                JenkinsJobDetails.ArtifactDetails jobStatusTmp = new JenkinsJobDetails.ArtifactDetails();
                JenkinsJobDetails.JobStatus jobStatus;
                for(Deployment__c dep: [SELECT Id, Name, User_Name__c , Branch_Name__c, Project_Name__c, 
                                        Pipeline_Owner__c, Time_to_Complete__c, CreatedDate,
                                        (SELECT Id, Name, Stage_Level__c, Order__c, Deployment__c, Status__c,
                                        Build_Number__c, Stage_URL__c, Completion_Time__c
                                        FROM Deployment_Stages__r ORDER BY Order__c, Stage_Level__c ASC)
                                        FROM Deployment__c WHERE Release__c =: releaseId AND Release_checklist__c =: checklistId 
                                        AND RM_Configuration__c =: selectedOrg ORDER BY Build_Number__c DESC limit 1]){
                    //Iterate over stages list /// Source_Org__c =: sourceOrg AND Target_Org__c =: targetOrg
                    for(Deployment_Stage__c stage: dep.Deployment_Stages__r){
                        System.debug('*** Stage *** '+stage.Name+' *** Order *** '+stage.Order__c+' *** Level *** '+stage.Stage_Level__c);
                        if(!String.isEmpty(prevStatus) && (prevStatus.equals('In Progress') || prevStatus.equals('Failure') || prevStatus.equals('Aborted')) && prevOrder == Integer.valueOf(stage.Order__c)){
                            continue;
                        }
                        else{
                            String url = stage.Stage_URL__c + ''+stage.Build_Number__c+'/api/json?pretty=true';
                            
                            jobStatus = DeploymentControllerService.viewJobStatus(url, jenkinsUser);
                            if(stage.Stage_Level__c == 0 && stage.Status__c.equals('Success')){
                                String str = JSON.serialize(jobStatus);
                                jobStatusTmp = (JenkinsJobDetails.ArtifactDetails)JSON.deserialize(str, JenkinsJobDetails.ArtifactDetails.class);
                                System.debug('*** jobStatusTmp *** '+jobStatusTmp );
                            }
                            stage.Completion_Time__c = jobStatus.duration;
                            String status = DeploymentControllerService.getStatus(jobStatus.result, jobStatus.building);
                            if(status.equals('Aborted')){
                                stage.Status__c = 'Aborted';
                                stage.Comments__c = 'This pipeline is aborted';
                            }
                            else if(prevStatus.equals('Success') && status.equals('Pending') && stage.Order__c == 0 && prevOrder == Integer.valueOf(stage.Order__c)){
                                stage.Status__c = 'In Progress';
                            }
                            else{
                                stage.Status__c = status;
                            }
                            prevStatus = status;
                            prevOrder = Integer.valueOf(stage.Order__c);
                            
                            stagesList.add(stage);
                            if(cnt == 0){
                                dep.Pipeline_Owner__c = jenkinsUser.Jenkins_User_Name__c;
                                //Check if branch and user name is updated or not. If not, update else skip
                                if(String.isEmpty(dep.User_Name__c) || String.isEmpty(dep.Branch_Name__c)){
                                    for(JenkinsJobDetails.actions actions: jobStatus.actions){
                                        if(actions.parameters != null && !actions.parameters.isEmpty()){
                                            for(JenkinsJobDetails.parameters pars: actions.parameters){
                                                if(pars.name.equalsIgnoreCase('SALESFORCE_USERNAME')){
                                                    dep.User_Name__c = pars.value;
                                                    break;
                                                }
                                            }
                                        }
                                        
                                        if(actions.remoteUrls != null && !actions.remoteUrls.isEmpty()){
                                            for(String projectName: actions.remoteUrls){
                                                List<String> projectNameList = projectName.split('/');
                                                projectNameList.remove(0);
                                                projectNameList.remove(0);
                                                projectNameList.remove(0);
                                                String gerritProjectName = String.join(projectNameList, '/');
                                                dep.Project_Name__c = gerritProjectName;
                                            }
                                        }
                                        
                                        if(actions.lastBuiltRevision != null){
                                            if(actions.lastBuiltRevision.branch != null && actions.lastBuiltRevision.branch.isEmpty() == false){
                                                for(JenkinsJobDetails.branch brch: actions.lastBuiltRevision.branch){
                                                    dep.Branch_Name__c = brch.name;
                                                    break;
                                                }
                                            }
                                        }
                                    }
                                    depList.add(dep);
                                }
                            }
                        }
                        cnt++;
                    }
                }
            
                if(!depList.isEmpty())
                update depList;
                
                if(!stagesList.isEmpty())
                update stagesList;
                
                if(stagesList[0].Stage_Level__c == 0 && stagesList[0].Status__c.equals('Success')){
                    List<Attachment> atList = [select Id, Name, Body from Attachment where ParentId =: stagesList[0].Id AND Name LIKE 'artifact%'];
                    if(atList.isEmpty()){
                        if(jobStatusTmp.artifacts != null){
                            /*System.debug('*** artifacts null *** '+jobStatus);
                            String str = JSON.serialize(jobStatus);
                            jobStatusTmp = (JenkinsJobDetails.ArtifactDetails)JSON.deserialize(str, JenkinsJobDetails.ArtifactDetails.class);
                        */
                        
                            String tmpDataStr = JSON.serialize(jobStatusTmp);
                            System.debug('*** tmpDataStr *** '+tmpDataStr);
                            DeploymentControllerService.createArtifactFile(stagesList[0].Id, tmpDataStr );
                        }
                    }
                    else{
                        //Generate artifact data
                        artifactMap = DeploymentControllerService.createArtifactData((atList[0].body).toString());
                        artifactSize = artifactMap.size();
                    }
                }
            }
            catch(Exception e){
                isError = true;
                errorMessage = 'ERROR: '+e.getMessage();
            }
        }
    } 
    
    public void fetchPipelineDetails(String selectedOrg, String checklistId, String releaseId){
        try{
            if(String.isBlank(selectedOrg)){
                isError = true;
                errorMessage = 'Please select deployment type';
            }
            else if(String.isBlank(checklistId)){
                isError = true;
                errorMessage = 'Please select checklist';
            }
            else if(String.isBlank(releaseId)){
                isError = true;
                errorMessage = 'Release Id not defined, please check your URL';
            }
            else{
                isError = false;
                jenkinsJobs = jobsSettingsMap.get(selectedOrg);
                jenkinsJob = jobsMap.get(selectedOrg);
                String sourceOrg = jenkinsJob.Source_Org__c;
                String targetOrg = jenkinsJob.Target_Org__c;
                pipelineList.clear();
                Integer cntSuccess = 0;
                Integer cntFailure = 0;
                Integer cntInProgress = 0;
                Integer cnt = 0;
                for(Deployment__c dep: [SELECT Id, Name, Release_checklist__c, Source_Org__c, Target_Org__c, 
                                        Release_checklist__r.Name, Pipeline_Owner__c, Time_to_Complete__c, CreatedDate,
                                        Build_Number__c, Status__c, Branch_Name__c, (SELECT Id, Name, Stage_Level__c, Order__c, Deployment__c,
                                         Status__c, Stage_Label__c, Stage_URL__c, Build_Number__c  
                                        FROM Deployment_Stages__r ORDER BY Order__c, Stage_Level__c ASC)
                                        FROM Deployment__c WHERE Release__c =: releaseId AND Release_checklist__c =: checklistId 
                                        AND RM_Configuration__c =: selectedOrg ORDER BY Build_Number__c DESC]){
                                        
                    system.debug('@@@@@@dep'+dep); 
                    Map<Integer, Map<Integer, PipelineStages>> orderStagesMap = new Map<Integer, Map<Integer, PipelineStages>>();
                    Map<Integer, Map<Integer, PipelineStages>> orderStagesMap2 = new Map<Integer, Map<Integer, PipelineStages>>();
                    
                    if(cnt == 0){
                        for(Deployment_Stage__c stage: dep.Deployment_Stages__r){
                            String cssClass = '';
                            String prevClass = '';
                            if(stage.Stage_Level__c == 0 && artifactMap.isEmpty()){
                                List<Attachment> atList = [select Id, Name, Body from Attachment where ParentId =: stage.Id AND Name LIKE 'artifact%'];
                                if(!atList.isEmpty())
                                artifactMap = DeploymentControllerService.createArtifactData((atList[0].body).toString() );
                                artifactSize = artifactMap.size();
                            }
                            System.debug('*** stage Name *** '+stage.Name+' *** Order *** '+stage.Order__c+' *** Level *** '+stage.Stage_Level__c);
                            if(orderStagesMap.get(Integer.valueOf(stage.Order__c)) == null){
                                System.debug('*** New Order *** '+stage.Order__c);
                                orderStagesMap.put(Integer.valueOf(stage.Order__c), new Map<Integer, PipelineStages>());
                                System.debug('*** Map with new Order *** '+orderStagesMap);
                                //Check if order is not 0
                                if(stage.Order__c != 0){
                                    System.debug('*** Order greater than 0 *** ');
                                    //Check all stages before current level
                                    for(PipelineStages st: orderStagesMap.get(Integer.valueOf(stage.Order__c)-1).values()){
                                        System.debug('*** Previous order stage Name *** '+st.stage.Name+' *** Order *** '+st.stage.Order__c+' *** Level *** '+st.stage.Stage_Level__c);
                                        //Check if stage level is less than current stage
                                        if(Integer.valueOf(st.stage.Stage_Level__c) < Integer.valueOf(stage.Stage_Level__c)){
                                            System.debug('*** Level is smaller than current level *** '+st.stage.Stage_Level__c);
                                            //remove css class
                                            PipelineStages stg = new PipelineStages(st.Stage, 'slds-is-hidden', false);
                                            prevClass = 'slds-is-hidden';
                                            //Put stage record in map
                                            System.debug('*** Addng Prev Stage to next order *** '+stage.Order__c);
                                            orderStagesMap.get(Integer.valueOf(stage.Order__c)).put(Integer.valueOf(stg.stage.Stage_Level__c), stg);
                                        }
                                        else{
                                            System.debug('*** Level is greater than current level *** '+st.stage.Stage_Level__c);
                                            //remove css class
                                            PipelineStages stg = new PipelineStages(st.Stage, 'slds-is-hidden', false);
                                            //Put stage record in map
                                            System.debug('*** Addng Prev Stage to next order *** '+stage.Order__c);
                                            orderStagesMap.get(Integer.valueOf(stage.Order__c)).put(Integer.valueOf(stg.stage.Stage_Level__c), stg);
                                        }
                                    }
                                }
                            }
                            else{
                                System.debug('*** Existing Order *** '+stage.Order__c);
                                //Check if order is not 0
                                if(stage.Order__c != 0){
                                    System.debug('*** Order > 0 ***');
                                    //Check all stages before current level
                                    Map<Integer, PipelineStages> orderMap = orderStagesMap.get(Integer.valueOf(stage.Order__c)-1);
                                    System.debug('*** Previous Order Map *** '+orderMap);
                                    Map<Integer, PipelineStages> currentOrderMap = orderStagesMap.get(Integer.valueOf(stage.Order__c));
                                    System.debug('*** Current Order Map *** '+currentOrderMap);
                                    for(PipelineStages st: orderMap.values()){
                                        System.debug('*** Previous Order Stage *** '+st.stage.Name);
                                        //Check if stage level is less than current stage
                                        if(Integer.valueOf(st.stage.Stage_Level__c) < Integer.valueOf(stage.Stage_Level__c)){
                                            System.debug('*** Level *** '+st.stage.Stage_Level__c+' < current Level *** '+stage.Stage_Level__c);
                                            if(currentOrderMap.containsKey(Integer.valueOf(st.stage.Stage_Level__c))){
                                                //do nothing
                                                System.debug('*** Current Map contains Stage Level *** '+stage.Stage_Level__c);
                                            }
                                            else{
                                                System.debug('*** Current Map does not contain stage level *** '+stage.Stage_Level__c);
                                                //remove css class
                                                PipelineStages stg = new PipelineStages(st.Stage, 'slds-is-hidden', false);
                                                prevClass = 'slds-is-hidden';
                                                //Put stage record in map
                                                orderStagesMap.get(Integer.valueOf(stage.Order__c)).put(Integer.valueOf(stg.stage.Stage_Level__c), stg);
                                            }
                                        }
                                        else{
                                            System.debug('*** Adding higher level steps *** '+st.stage.Stage_Level__c);
                                            //remove css class
                                            PipelineStages stg = new PipelineStages(st.Stage, 'slds-is-hidden', false);
                                            //Put stage record in map
                                            orderStagesMap.get(Integer.valueOf(stage.Order__c)).put(Integer.valueOf(stg.stage.Stage_Level__c), stg);
                                        }
                                    }
                                }
                            }
                            
                            if(stage.Status__c.equals('Success')){
                                cssClass = 'slds-is-complete';
                            }
                            else if(stage.Status__c.equals('Failure')){
                                cssClass = 'slds-is-lost';
                            }
                            else if(stage.Status__c.equals('In Progress')){
                                cssClass = 'slds-is-current';
                            }
                            else if(stage.Status__c.equals('Aborted')){
                                cssClass = 'slds-is-aborted';
                            }
                            else{
                                cssClass = 'slds-is-incomplete';
                            }
                            if(prevClass.equals('slds-is-hidden')){
                                cssClass = cssClass + ' slds-is-hidden';
                            }
                            PipelineStages stageObj = new PipelineStages(stage, cssClass, true);
                            //Add to map
                            System.debug('*** Adding stage Name *** '+stage.Name+' *** Order *** '+stage.Order__c+' *** Level *** '+stageObj.stage.Stage_Level__c);
                            orderStagesMap.get(Integer.valueOf(stage.Order__c)).put(Integer.valueOf(stageObj.stage.Stage_Level__c), stageObj);
                            //stagesList.add(stageObj);
                            
                        }
                        
                        System.debug('*** Creating new Map ***');
                        for(Integer i: orderStagesMap.keySet()){
                            if(i==0){
                                orderStagesMap2.put(i, orderStagesMap.get(i));
                            }
                            else{
                                System.debug('*** '+i+' > 0 ***');
                                Map<Integer, PipelineStages> tmpMap = new Map<Integer, PipelineStages>();
                                Map<Integer, PipelineStages> tmpMap1 = orderStagesMap.get(i);
                                System.debug('*** Current Map *** '+tmpMap1);
                                for(Integer j: tmpMap1.keySet()){
                                    System.debug('*** Adding level in tmp map *** '+j);
                                    tmpMap.put(j, tmpMap1.get(j));
                                }
                                Map<Integer, PipelineStages> tmpMap2 = orderStagesMap.get(i-1);
                                System.debug('*** Previous Map *** '+tmpMap2);
                                for(Integer j: tmpMap2.keySet()){
                                    System.debug('*** current Level *** '+j);
                                    if(!tmpMap.containsKey(j)){
                                        System.debug('*** tmpMap does not contains level *** '+j);
                                        PipelineStages stg = new PipelineStages(tmpMap2.get(j).Stage, '', false);
                                        System.debug(' *** Adding stage *** '+stg.stage.Name);
                                        tmpMap.put(j, stg);
                                    }
                                    else{
                                        System.debug('*** tmpMap contains level '+j);
                                    }
                                }
                                System.debug('*** adding at order *** '+i+' *** Values *** '+tmpMap);
                                orderStagesMap2.put(i, tmpMap);
                            }
                        }
                        System.debug('*** orderStagesMap *** '+orderStagesMap);
                        List<PipelineOrder> pipelineOrderList = new List<PipelineOrder>();
                        for(Integer i: orderStagesMap2.keySet()){
                            PipelineOrder order = new PipelineOrder(i, orderStagesMap2.get(i).values());
                            pipelineOrderList.add(order);
                        }
                        PipelineDetails pipeline = new PipelineDetails(dep, pipelineOrderList);
                        pipelineList.add(pipeline); 
                    
                        //Allow refresh or not
                        if(!pipelineList.isEmpty()){
                            if(pipelineList[0].deployment.Status__c.equals('Success') || pipelineList[0].deployment.Status__c.equals('Failed') || pipelineList[0].deployment.Status__c.equals('Pending')){
                                refreshContinue = false;
                            }
                            else{
                                refreshContinue = true;
                            }
                        }
                        else{
                            refreshContinue = false;
                        }
                    }
                    
                    cnt++;
                    //Get success count and failure count
                    if(dep.Status__c.equals('Success')){
                        cntSuccess++;
                    }
                    else if(dep.Status__c.equals('Failed')){
                        cntFailure++;
                    }
                    else{
                        cntInProgress++;
                    }
                }
            }
            //Mark all pre-deployment steps incomplete
            if(!refreshContinue && buildTriggered){
                DeploymentControllerService.updateDeploymentActivities(jenkinsJob.Target_Environment__c, checklistId);
                buildTriggered = false;
                manualStepsCompleted  = checkManualSteps(selectedOrg, selectedChecklist);
            }
        }
        catch(Exception e){
            isError = true;
            errorMessage = 'ERROR: '+e.getMessage();
            
        }
    }
    
    
    
  /*  public class series{
        public String seriesname{ get; set; }
        public List<data> data{ get; set; }
        
        public series(String seriesname, List<data> data){
            this.seriesname = seriesname;
            this.data = data;
        }
    }*/
    
  /*  public class data{
        public String value{ get; set; }
        public data(String value){
            this.value = value;
        }
    }*/
    
    public class PipelineDetails{
        public Deployment__c deployment{ get; set; }
        public List<PipelineStages> stagesList{ get; set; }
        public List<PipelineOrder> orderList{ get; set; }
        public PipelineDetails(Deployment__c deployment, List<PipelineOrder> orderList){
            this.deployment = deployment;
            this.orderList = orderList;
        }
    }
    
    public class PipelineOrder{
        public Integer pipelineOrderNo{ get; set; } //Level based on stage level
        public List<PipelineStages> stageList{ get; set; } //Stages at particular level
        public PipelineOrder(Integer pipelineOrderNo, List<PipelineStages> stageList){
            this.pipelineOrderNo = pipelineOrderNo;
            this.stageList = stageList;
        }
    }
    
    public class PipelineStages{
        public Deployment_Stage__c stage{ get; set; }
        public String stageClass{ get; set; }
        public Boolean displayName{ get; set; }
        public PipelineStages(Deployment_Stage__c stage, String stageClass, Boolean displayName){
            this.stage = stage;
            this.stageClass = stageClass;
            this.displayName = displayName;
        }
    }
  /*  
    public class DashboardDetails{
        public String sourceOrg{ get; set; }
        public String targetOrg{ get; set; }
        public Integer totalDeployments{ get; set; }
        public Integer successfulDeployments{ get; set; }
        public Integer failedDeployments{ get; set; }
        public Integer inProgressDeployments{ get; set; }
        public Integer pendingDeployments{ get; set; }
        public Date startDate{ get; set; }
        public Date endDate{ get; set; }
    }*/
    
    public PageReference triggerJenkinsJob(){
        if(String.isBlank(selectedOrg)){
            isError = true;
            errorMessage = 'Please select deployment type';
        }
        else if(String.isBlank(selectedChecklist)){
            isError = true;
            errorMessage = 'Please select checklist';
        }
        else if(releaseObj == null){
            isError = true;
            errorMessage = 'Release Id not defined, please check your URL';
        }
        else if(jenkinsUser == null || (jenkinsUser != null && !jenkinsUser.Jenkins_User_Active__c)){
            isError = true;
            errorMessage = 'Jenkins user not found for you. Please add Jenkins user from Settigs tab';
        }
        else{
            String MESSAGE = '';
            try{
                isError = false;
                jenkinsJobs = jobsSettingsMap.get(selectedOrg);
                jenkinsJob = jobsMap.get(selectedOrg);
                Http http = new Http();
                HTTPRequest req = new HTTPRequest();
                String parameters = DeploymentControllerService.formatParameters(jenkinsJob);
                System.debug('*** parameters *** '+parameters );
                req.setEndpoint(jenkinsJob.Job_URL__c+'/buildWithParameters?token='+jenkinsJob.Job_Token__c);
                System.debug('***EndpointURL *** '+jenkinsJob.Job_URL__c+'/buildWithParameters?token='+jenkinsJob.Job_Token__c );
                Blob headerValue = Blob.valueOf(jenkinsUser.Jenkins_User_Name__c+ ':' + jenkinsUser.Jenkins_Password__c);
                String authorizationHeader = 'Basic ' + EncodingUtil.base64Encode(headerValue);
                
                system.debug(authorizationHeader);
                req.setHeader('Authorization', authorizationHeader);
                req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
                req.setMethod('POST');
                
                /*if(string.isnotblank(jenkinsJob.Parameters__c)){
                    req.setBody(jenkinsJob.Parameters__c.escapeHtml4());
                }*/
                
                HTTPResponse resp = http.send(req);
                system.debug('*** Response *** '+resp);
                if(resp.getstatuscode() == 201){
                    jobStarted = true;
                    createDeployment = true;
                    buildTriggered = true;
                    return null;
                }
                else if(resp.getstatuscode() == 401){
                    isError = true;
                    jobStarted = createDeployment = false;
                    errorMessage = Label.Unauthorized_User;
                    return null;
                }
                else if(resp.getstatuscode() == 500){
                    isError = true;
                    jobStarted = createDeployment = false;
                    errorMessage = Label.Internal_Server_Error;
                    return null;
                }
                //jobStarted = true;
                //createDeployment = true;
            }catch(Exception e){
                jobStarted = false;
                isError = true;
                errorMessage = e.getMessage();
                createDeployment = false;
                system.debug(e);
                return null;
                
            }
        }
        
        return null;
    }
    
    public PageReference refresh(){
        try{
            updateStageStatus(selectedOrg, selectedChecklist, releaseObj.Id);
            fetchPipelineDetails(selectedOrg, selectedChecklist, releaseObj.Id);
        }
        catch(Exception e){
            isError = true;
            errorMessage = 'ERROR: '+e.getMessage();
           
        }
        return null;
    }
    
    public PageReference createRecords(){
        try{
            createReleaseStatusRecords(selectedOrg, selectedChecklist, releaseObj.Id);
            fetchPipelineDetails(selectedOrg, selectedChecklist, releaseObj.Id);
        }
        catch(Exception e){
            isError = true;
            errorMessage = 'ERROR: '+e.getMessage();
        }
        return null;
    }
    
    public List<Manual_Steps_Environments__c> manualStepList{ get; set; }
    
    public pageReference viewStepTrackerRecords(){
        try{
            if(String.isBlank(selectedChecklist)){
                isError = true;
                errorMessage = 'Please select checklist';
            }
            else{
                manualStepList = new List<Manual_Steps_Environments__c>();
                manualStepList = [Select Id, Name,Is_Completed__c, Manual_Steps__r.Steps_to_perform__c, 
                                  Manual_Steps__r.Name, Manual_Steps__r.Component__c from Manual_Steps_Environments__c
                                  where SF_Environment__c =: jenkinsJob.Target_Environment__c
                                  AND Manual_Steps__r.Release_checklist__c =: selectedChecklist];
                showStepTrackers = true;
            }
        }
        catch(Exception e){
            isError = true;
            errorMessage = 'ERROR: '+e.getMessage();
        }
        return null;
    }
    
    public pageReference cancelStepTrackers(){
        showStepTrackers = false;
        isError = false;
        return null;
    }
    
    public pageReference hideErrorPopup(){
        isError = false;
        return null;
    }
    
    
    public PageReference saveStepTrackers(){
        try{
            update manualStepList;
            showStepTrackers = false;
            String selOrg = selectedOrg;
            selectRelease();
            selectedOrg = selOrg;
            selectOrg();
            manualStepsCompleted  = checkManualSteps(selectedOrg, selectedChecklist);
        }catch(Exception e){
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'Error while saving step tracker records: '+e.getMessage()));
            showStepTrackers = false;
        }
        return null;
    }
    
    public void createReleaseStatusRecords(String selectedOrg, String checklistId, String releaseId){
        if(jenkinsUser == null || (jenkinsUser != null && !jenkinsUser.Jenkins_User_Active__c)){
            isError = true;
            errorMessage = 'Jenkins user not found for you. Please add Jenkins user from Settigs tab';
        }
        else{
            DeploymentControllerService service = new DeploymentControllerService();
            service.createJobs(jenkinsJob.Job_URL__c+'/api/json?pretty=true', 0, 0, jenkinsUser);
            /*Decimal cnt = service.stagesList[0].Build_Number__c;
            if(cnt != 0){
                cnt = cnt-1;
            }
            Integer count = [select count() from Deployment__c where Release__c =: releaseId AND Release_checklist__c =: checklistId and Build_Number__c =: cnt];
            if(count > 0){
                cnt = cnt + 1;
            }
            else{
                service.stagesList[0].Build_Number__c = service.stagesList[0].Build_Number__c - 1;
            }*/
            
            //Create Deployment Object
            Deployment__c deploymentObj = new Deployment__c();
            deploymentObj.Name = 'Build #'+service.stagesList[0].Build_Number__c;
            deploymentObj.Release__c = releaseId;
            deploymentObj.Release_checklist__c = checklistId;
            deploymentObj.Build_Number__c = service.stagesList[0].Build_Number__c;
            deploymentObj.Source_Org__c = jenkinsJob.Source_Org__c;
            deploymentObj.Target_Org__c = jenkinsJob.Target_Org__c;
            deploymentObj.RM_Configuration__c = selectedOrg; //jobsMap.get(selectedOrg).Target_Environment__c;
            insert deploymentObj;
            
            for(Deployment_Stage__c stage: service.stagesList){
                
                stage.Deployment__c = deploymentObj.Id;
            }
            service.stagesList[0].Status__c = 'In Progress';
            try{
                insert service.stagesList;
            }
            catch(Exception e){
                isError = true;
                errorMessage = 'ERROR: '+e.getMessage();
            }
        }
    }
    
    
    public class StageLogDocuments{
        public Attachment doc{ get; set; }
        public String fileType{ get; set; }
        public StageLogDocuments(Attachment doc, String fileType){
            this.doc = doc;
            this.fileType = fileType;
        }
    }
    
    /*public class stageSummary{
        public String summaryData{ get; set; }
        public Id id{ get; set; }
        public stageSummary(String summaryData, Id id){
            this.summaryData = summaryData;
            this.Id = id;
        }
    }*/
    
    public PageReference readStageLog(){
        String jobName = ApexPages.CurrentPage().getParameters().get('jobName');
        docList = new List<Attachment>();
        newdocList = new List<StageLogDocuments>();
        System.debug('*** jobName *** '+jobName);
        try{
            if(!String.isEmpty(jobName)){
                Deployment_Stage__c stageObj = [select Id, Status__c from Deployment_Stage__c where Id=: jobName];
                if(stageObj != null && (stageObj.Status__c == 'Success' || stageObj.Status__c == 'Failure')){
                    docList = [Select Id, ContentType, Name, Parent.Name, Body from Attachment where Parent.Id =:jobName];
                    
                    if(docList != null && docList.isEmpty() == false){
                        Integer cnt = 0;
                        showLog = true;
                        for(Attachment att: docList){
                            System.debug('*** file Name *** '+att.Name);
                            logStageName = att.Parent.Name;
                            if( att.Name.endsWith('.log')){
                                currentLog = att; //docList[0];
                            }
                            System.debug('<------Test-----> '+att.Name);
                            if(att.Name.endsWith('html') || att.Name.endsWith('htm')){
                                Blob bodyBlob; // = att.Body;
                                if(att.Parent.Name.containsIgnoreCase('Diff')){
                                    if(att.Name.equals('Home_Summary.html')){
                                        System.debug('*** Summary2 *** '+att.Name);
                                        String body = DeploymentControllerService.replaceURLs(att.Body.toString(), docList);
                                        bodyBlob = Blob.valueOf(body);
                                        cnt++;
                                    }
                                }
                                else if(att.Parent.Name.containsIgnoreCase('TAS')){
                                    if(att.Name.equals('index.html')){
                                        System.debug('*** TAS *** '+att.Name);
                                        bodyBlob = att.Body;
                                        cnt++;
                                    }
                                }
                                else{
                                    System.debug('*** !!! Summary2 *** '+att.Name);
                                    bodyBlob = att.Body;
                                    cnt++;
                                }
                                
                                System.debug('*** bodyBlob *** '+bodyBlob );
                                if(bodyBlob != null){
                                    String strHTML = bodyBlob.toString();
                                    System.debug('*** strHTML *** '+strHTML);
                                    summary = strHTML;
                                }
                            }
                            Integer strtInd = att.Name.LastIndexOf('.');
                            
                            String fileType = att.Name.subString(strtInd+1, att.Name.Length());
                            System.debug('*** fileType *** '+fileType);
                            if(!att.Name.containsIgnoreCase('artifact'))
                            newdocList.add(new StageLogDocuments(att, fileType));
                            
                            if(att.Name.endsWith('.log') && (att.Parent.Name.containsIgnoreCase('deploy_CI') || att.Parent.Name.containsIgnoreCase('Validation'))){
                                getDeploymentStatus(att.body.toString(), stageObj.Status__c);
                            }
                            
                        }
                    }
                    else{
                        isError = true;
                        errorMessage = 'Log file is not available yet. Please try after sometime';
                        showLog = false;
                        return null;
                    }
                }
                else{
                    isError = true;
                    errorMessage = 'You can view log only when job is completed';
                    showLog = false;
                    return null;
                }
            }
        }
        catch(Exception e){
            isError = true;
            showLog = false;
            errorMessage = 'ERROR: '+e.getMessage();
        }
        return null;
    }
    
    public String chartDataString{ get; set; }
    public String chartDataStringFail{ get; set;}
    public String chartTestData{ get; set; }
    public Integer totalComp{ get; set; }
    public List<DeploymentDetailsUtils.DeployMessage> failureList{ get; set;}
    
    public String deploymentId{ get; set; }
    public String authId{ get; set; }
    public String instanceURL{ get; set; }
    
    public void getDeploymentStatus(String logBody, String jobStatus){
        
        String startString = (jobStatus.equalsIgnoreCase('Success'))?'Finished request ':'Request ID: ';
        System.debug('*** logbody *** '+logBody);
        deploymentId = DeploymentStatusController.getDeploymentJobId(logBody, startString);
        System.debug('*** deploymentId *** '+deploymentId);
        if(String.isBlank(deploymentId)){
            System.debug('*** deploymentId is blank *** ');
            showLog = true;
        }
        else{
            DeploymentStatusController.token authObj = DeploymentStatusController.authorize(jobsMap.get(selectedOrg).Target_Environment__c);
            if(authObj.access_token == null){
                isError = true;
                showLog = false;
                errorMessage = 'Authorization failed. Please check credentials for target org associated with job '+jobsMap.get(selectedOrg).Name;
            }
            else{
                //deploymentId = depId;
                authId = authObj.access_token;
                instanceURL = authObj.instance_url;
                DeploymentDetailsUtils.DeployResult deployResult = DeploymentStatusController.getDeploymentStatus(authId, instanceURL, deploymentId);
                parseDeployResult(deployResult);
            }
        }
    }
    
    public PageReference exportErrorReport(){
        String depId = ApexPages.CurrentPage().getParameters().get('d');
        String authKey = ApexPages.CurrentPage().getParameters().get('a');
        String orgUrl = ApexPages.CurrentPage().getParameters().get('i');
        DeploymentDetailsUtils.DeployResult deployResult = DeploymentStatusController.getDeploymentStatus(authKey, orgUrl, depId);
        parseDeployResult(deployResult);
        return null;
    }
    
    public void parseDeployResult(DeploymentDetailsUtils.DeployResult deployResult ){
        
        if(deployResult != null){
            totalComp = deployResult.details.componentSuccesses.size();
                
            if(deployResult.details.componentFailures != null){
                failureList = new List<DeploymentDetailsUtils.DeployMessage>();
                failureList = deployResult.details.componentFailures;
            }
            else{
                chartDataString = DeploymentStatusController.generateChartData(deployResult.details.componentSuccesses);
                system.debug('----chartDataString -----'+chartDataString );
                //chartDataStringFail =(DeploymentStatusController.generateChartData(deployResult.details.componentFailures)== null)? null:DeploymentStatusController.generateChartData(deployResult.details.componentFailures);
                chartTestData = DeploymentStatusController.generateTestRunningData(deployResult.details.runTestResult);
            }
        }
    }
    
    public PageReference exitLog(){
        showLog = false;
        logBody = '';
        summary = '';
        return null;
    }
    public PageReference showNewRelease(){
        rel = new Release__c();
        showReleaseWin= true;
        isError = false;
        errorMessage = '';
        return null;
    }
    
    public PageReference hideNewRelease(){
        showReleaseWin= false;
        isError = false;
        errorMessage = '';
        return null;
    }
    
    public PageReference saveRelease() {
        isError = false;
        errorMessage = '';
        System.debug('*** rel *** '+rel);
        if(String.isBlank(rel.Name)){
            isError = true;
            errorMessage = Label.Required_Field;
            return null;
        }
        try{
            insert rel; 
            showReleaseWin = false;
            isError = false;
            errorMessage = '';
            fetchReleaseRecords();
        }
        catch(Exception e){
            isError = false;
            errorMessage = e.getMessage();
        }
        return null; 
    }
    
    public PageReference submitForApproval(){
    System.debug('*** Approval1 *** '+releaseObj.Id);
            try{
                System.debug('*****UserTest '+releaseObj.user__c);
                if(releaseObj.user__c != null){
                    Approval.ProcessSubmitRequest Req = new Approval.ProcessSubmitRequest();
                    Req.setObjectId(releaseObj.Id);                
                    System.debug('*** Approval2 *** '+releaseObj.Id);
                    req.setNextApproverIds(new Id[] {releaseObj.user__c});
                    ApprovalStep= false;
                    Approval.ProcessResult result = Approval.process(Req);
                }
            }catch (Exception ex){
                System.debug('*** Approval3 *** '+releaseObj.Id);
                if(ex.getTypeName()=='System.DmlException'){
                    approvalErrMsg=ex.getDmlMessage(0);
                }
                else{
                    approvalErrMsg=ex.getMessage();
                    System.debug('*** Approval4 *** '+releaseObj.Id);
                }
            }
            ApprovalStep= false;
            releaseObj = [SELECT Id,OwnerId,Owner.Name,User__c, Name,Approval_Status__c,RecordType.name,Deployment_Approval_Required__c,On_Demand_Validation_Needed__c, Release_Start_Date__c, Release_Planned_End_Date__c, Production_Deploy_Approved__c,
                                    Prod_Validation_Complete__c FROM Release__c WHERE Id = :releaseObj.Id];
            return null;
        }
        
   public pageReference cancelApprovalProcess(){
        ApprovalStep= false;
        return null;
    }
    
    public pageReference ApprovalProcessCall(){
        ApprovalStep= true;
        return null;
    }
    public String jobUrl{ get; set; }
    
    public PageReference triggerOnDemandValidationJob(){
        if(jenkinsUser == null || (jenkinsUser != null && !jenkinsUser.Jenkins_User_Active__c)){
            isError = true;
            errorMessage = 'Jenkins user not found for you. Please add Jenkins user from Settigs tab';
        }
        else{
            jenkinsJob = jobsMap.get(selectedOrg);
            system.debug('>>>releaseObj.Prod_Validation_Complete__c >>>'+releaseObj.Prod_Validation_Complete__c );
            if(releaseObj.Prod_Validation_Complete__c == 'In Progress'){
                JenkinsJobDetails.JobStatus status = DeploymentControllerService.viewJobStatus(jobUrl, jenkinsUser);
                String checkStatus = DeploymentControllerService.getStatus(status.result, status.building);
                if(checkStatus.equals('Success')){
                    releaseObj.Prod_Validation_Complete__c = 'Success';
                    update releaseObj;
                    releaseObj = DeploymentControllerService.fetchReleaseRecord(releaseObj.Id);
                }
                else if(checkStatus.equals('Failure')){
                    releaseObj.Prod_Validation_Complete__c = 'Error';
                    update releaseObj;
                    releaseObj = DeploymentControllerService.fetchReleaseRecord(releaseObj.Id);
                }
            }
            else{
                String jobStatus = DeploymentControllerService.triggerOnDemandValidationJob(jenkinsJob, jenkinsUser);
                if(jobStatus.contains('SUCCESS')){
                    releaseObj.Prod_Validation_Complete__c = 'In Progress';
                    update releaseObj;
                    
                    jobUrl = jenkinsJob.On_Demand_Validation_Job_URL__c+''+jobStatus.split(':')[1]+'/api/json?pretty=true';
                    
                    releaseObj = DeploymentControllerService.fetchReleaseRecord(releaseObj.Id);
                }
                else{
                    isError = true;
                    errorMessage = jobStatus.split(':')[1];
                }
            }
        }
        return null;
    }
    
    public Boolean triggerJob{ get; set; }
    
    public PageReference checkDeploymentComponents(){
        if(jenkinsUser == null || (jenkinsUser != null && !jenkinsUser.Jenkins_User_Active__c)){
            isError = true;
            errorMessage = 'Jenkins user not found for you. Please add Jenkins user from Settigs tab';
        }
        else{
            jenkinsJob = jobsMap.get(selectedOrg);
            if(jenkinsJob == null){
                isError = true;
                errorMessage = 'Please select Jenkins Job first';
                //return null;
            }
            else if(!triggerJob && !jobCompleted){
                JenkinsJobDetails.JobStatus status = DeploymentControllerService.viewJobStatus(jobUrl, jenkinsUser);
                String checkStatus = DeploymentControllerService.getStatus(status.result, status.building);
                if(checkStatus.equals('Success') || checkStatus.equals('Failure')){
                    jobCompleted = true;
                    viewComponents = true;
                    String str = JSON.serialize(status);
                    deploymentComponentData = (JenkinsJobDetails.ArtifactDetails)JSON.deserialize(str, JenkinsJobDetails.ArtifactDetails.class);
                    System.debug('*** checkDeploymentComponents deploymentComponentData *** '+deploymentComponentData);
                    artifactMap = DeploymentControllerService.createArtifactData(JSON.serialize(deploymentComponentData));
                    artifactSize = artifactMap.size();
                }
                else {
                    viewComponents = false;
                    jobCompleted = false;
                }
                
            }
            else{
                triggerJob = false;
                HttpResponse resp = GerritDetails.makeCallout(jenkinsJob.On_Demand_Validation_Job_URL__c+'/buildWithParameters?token='+jenkinsJob.On_Demand_Job_Token__c, jenkinsUser, '', 'POST');
                String jobStatus;
                if(resp.getstatuscode() == 201){
                    JenkinsJobDetails details = DeploymentControllerService.viewJobStatus(jenkinsJob, jenkinsUser);
                    jobStatus = 'SUCCESS:'+((details.builds.isEmpty())?1:(details.builds[0].buildNumber+1));
                }
                else{
                    jobStatus = 'ERROR: '+resp.getStatus();
                }
                if(jobStatus.contains('SUCCESS')){
                    
                    jobUrl = jenkinsJob.On_Demand_Validation_Job_URL__c+''+jobStatus.split(':')[1]+'/api/json?pretty=true';
                    jobCompleted = false;
                    viewComponents = false;
                }
                else{
                    isError = true;
                    errorMessage = jobStatus.split(':')[1];
                }
            }
        }
        return null;
    }
    
    public PageReference exitViewComponent(){
        viewComponents = false;
        jobCompleted = false;
        triggerJob = true;
        return null;
    }
    
    public List<ManualStepsController.SFOrgsDetails> sfOrgList{ get; set; }
    ManualStepsController mscontObj = new ManualStepsController();
    
    public PageReference createManualSteps(){
        sfOrgList = new List<ManualStepsController.SFOrgsDetails>();
        manualStep = new Manual_steps_tracker__c();
        Map<String, String> recTypeMap = DeploymentControllerService.getRecordTypeByObjectName(Label.Manual_Steps);
        recTypeId = '';
        recTypeList.clear();
        recTypeList.add(new SelectOption('', '-None-'));
        for(String s: recTypeMap.keySet()){
            recTypeList.add(new SelectOption(s, recTypeMap.get(s)));
        }
        sfOrgList.clear();
        sfOrgList = mscontObj.fetchSFOrgsList();
        System.debug('**sfOrgList**'+sfOrgList);
        showStepTrackers1 = true;
        fieldRequired = false;
        return null;
    }
    
    public PageReference cancelStepTrackersCreate(){
        showStepTrackers1 = false;
        return null;
    }
    
    public PageReference createStepTrackers(){
        if(String.isEmpty(manualStep.Steps_to_perform__c)){
            fieldRequired = true;
            return null;
        }
        else if(String.isEmpty(manualStep.Component__c)){
            fieldRequired = true;
            return null;
        }
        else{
            try{
                manualStep.Release_checklist__c = selectedChecklist;
                
                manualStep.RecordTypeId = recTypeId;
                System.debug('**RecordID**'+recTypeId);
                insert manualStep;
                
                mscontObj.createApplicableOrgs(new List<Manual_steps_tracker__c>{manualStep} , sfOrgList);
                
                showStepTrackers1 = false;
                String selOrg = selectedOrg;
                selectRelease();
                selectedOrg = selOrg;
                selectOrg();
                manualStepsCompleted  = checkManualSteps(selectedOrg, selectedChecklist);
                return null;
            }
            catch(Exception e){
                isError = true;
                errorMessage = e.getMessage();
                return null;
            }
        }
    }
    
    public PageReference stopPipelineJob(){
        if(jenkinsUser == null || (jenkinsUser != null && !jenkinsUser.Jenkins_User_Active__c)){
            isError = true;
            errorMessage = 'Jenkins user not found for you. Please add Jenkins user from Settigs tab';
        }
        else{
            String url = ApexPages.CurrentPage().getParameters().get('stageUrl');
            String buildNumber = ApexPages.CurrentPage().getParameters().get('buildNumber');
            System.debug('*** url *** '+url+' *** buildNumber *** '+buildNumber);
            if(!url.endsWith('/')){
                url += '/';
            }
            url = url+buildNumber+'/stop';
            
            HTTPResponse resp = GerritDetails.makeCallout(url, jenkinsUser, '', 'POST'); //http.send(req);
            if(resp.getStatusCode() == 200){
                refresh();
            }
        }
        return null;
    }
   /* 
    public PageReference startPipelineJob(){
        String url = ApexPages.CurrentPage().getParameters().get('stageUrl');
        String buildNumber = ApexPages.CurrentPage().getParameters().get('buildNumber');
        String jobId = ApexPages.CurrentPage().getParameters().get('jobId');
        System.debug('*** url *** '+url+' *** buildNumber *** '+buildNumber);
        if(!url.endsWith('/')){
            url += '/';
        }
        String parameters = DeploymentControllerService.formatParameters(jenkinsJob);
        url = url+buildNumber+'/rebuild/parameterized?token='+jenkinsJob.Job_Token__c+'&'+parameters;
        
        HTTPResponse resp = GerritDetails.makeCallout(url, jenkinsUser, '', 'POST'); //http.send(req);
        if(resp.getStatusCode() == 200){
            Deployment_Stage__c stage = [select Id, Build_Number__c from Deployment_Stage__c where Id=:jobId];
            stage.Build_Number__c = stage.Build_Number__c+1;
            //update stage;
            refresh();
        }
        return null;
    }*/
   
}