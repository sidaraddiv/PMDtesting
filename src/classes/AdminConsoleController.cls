/**
* @author : Prashant Wayal
* @date   : 20-Oct-2016
* @description : This class will act as a contronller class for AdminConsole page.
*                It contains all methods required for creating Jenkins Jobs, Manual Step records
*                and RM Configuration data.
*/
public class AdminConsoleController{
    
    //RM_Configuration__c Variables
    public RM_Configuration__c config{ get; set; } //Variable used to create RM Configuration data used 
    public RM_Configuration__c jenkinsUser{ get; set; } //Variable used to create Jenkins User
    public RM_Configuration__c jenkinsJobsObj{ get; set; } //Variable used to create/Update jenkins job
    public List<RM_Configuration__c> jenkinsUsersList{ get; set; } //Varaible to show jenkins users list available in database
    public List<RM_Configuration__c> JenkinsJobsListNew{ get; set; } //Variable to show all jenkins jobs added by admin
    public Map<String, RM_Configuration__c> jobsMap{ get; set; } //Variable to hold values of jenkins jobs
    
    //String variables
    public String errorMessage{ get; set; } //Variable to show Error Message Text to end user
    public static String urlRegex = Label.URL_REGEX; //Variable to hold regular expression for url validation
    public static String emailRegex = Label.Email_REGEX; //Variable to hold regular expression for email address validation
    public String recTypeId{ get; set; } //Manual Step Tracker record Type
    
    //Boolean Varaibles
    public Boolean isError{ get; set; } //Indicate if error occured or not
    public Boolean showStepTrackers{ get; set; } //Used to show panel for creating new manual step
    public Boolean fieldRequired{ get; set; } //Indicate a field is required
    public Boolean createForCurrentRelease{ get; set; } //Used to create a manual step for all in-progress releases
    public Boolean showJenkinsJobs{ get; set; } //Used to show panel on vf page for creating jenkins job
    public Boolean showJenkinsUsers{ get; set; } //Used to show panel on vf page for creating jenkins user
    
    //Default_Step_Tracker_Records__c Variables
    public Default_Step_Tracker_Records__c manualStep{ get; set; } //Variable to create new manual step
    public Map<String,Default_Step_Tracker_Records__c> defaultStepsMap{ get; set; } //Map to hold values of all default manual steps 
    public List<Default_Step_Tracker_Records__c> defaultStepsList{ get; set; } //List to show all available default manual steps
    
    //Integer Variables
    public Integer NoOfJobs{ get; set; } //Total number of jenkins jobs present in database
    public Integer stepsSize{ get; set; } //Total number of default manuals steps present in database
    
    //SelectOption List
    public List<SelectOption> recTypeList{ get; set; }
    
    
    //Constructor
    public AdminConsoleController(){
        config = readConfigData();
        showStepTrackers = isError = fieldRequired = showJenkinsJobs = false;
        createForCurrentRelease = false;
        JenkinsJobsListNew = new List<RM_Configuration__c>();
        jenkinsUsersList = new List<RM_Configuration__c>();
        jenkinsUser = new RM_Configuration__c();
        jobsMap = new Map<String, RM_Configuration__c>();
        defaultStepsMap = new Map<String,Default_Step_Tracker_Records__c>();
        defaultStepsList = new List<Default_Step_Tracker_Records__c>();
        recTypeList = new List<SelectOption>();
        
        defaultStepsList.clear();
        defaultStepsMap.clear();
        
        defaultStepsList = Default_Step_Tracker_Records__c.getAll().values();
        for(Default_Step_Tracker_Records__c step: defaultStepsList){
            defaultStepsMap.put(step.Id, step);
        }
        
        System.debug('*** defaultStepsMap  *** '+defaultStepsMap );
        stepsSize = defaultStepsMap.size();
        NoOfJobs = 0;
        jobsMap = fetchConfigData(fetchConfigData());
        NoOfJobs = jobsMap.size();
    }
    
    /*
    public List<Jenkins_Jobs__c> fetchJenkinsJobsList(){
        List<Jenkins_Jobs__c> jobsList = new List<Jenkins_Jobs__c>();
        jobsList = [select Id, Name, Job_Type__c, Target_Org__c, Salesforce_Username__c, Jenkins_Job_Name__c,
                    Package_To_Validate__c, Job_URL__c
                    from Jenkins_Jobs__c];
        return jobsList;
    }*/
    
    public static RM_Configuration__c readConfigData(){
        
        List<RM_Configuration__c> confList = [select Id, Name, Deployment_Approval_Required__c, Manual_Steps_Required__c, Max_of_Pipeline_to_Save__c,
                On_Demand_Validation_Needed__c, View_Dashboard__c, View_Pipeline__c, View_Pipeline_Log__c
                from RM_Configuration__c where RecordTypeId =:DeploymentControllerService.getRecordTypeIdByName(Label.RM_Configuration, Label.RM_Config) 
                order by LastModifiedDate limit 1];
        
        RM_Configuration__c confObj;
        if(confList == null || confList.isEmpty()){
            confObj = new RM_Configuration__c();
        }
        else{
            confObj = confList[0];
        }
            
        return confObj;
    }
    
    public static RM_Configuration__c readConfigData(List<RM_Configuration__c> confList){
        RM_Configuration__c confObj;
        if(confList == null || confList.isEmpty()){
            confObj = new RM_Configuration__c();
        }
        else{
            for(RM_Configuration__c config: confList){
                if(DeploymentControllerService.getRecordTypeIdByName(Label.RM_Configuration, Label.RM_Config) == config.recordTypeId){
                    confObj = config;
                    break;
                }
                else{
                    confObj = new RM_Configuration__c();
                }
            }
        }    
        return confObj;
    }
    
    public static Map<String, RM_Configuration__c> fetchConfigData(Map<String, RM_Configuration__c> configMap){
        
        Map<String, RM_Configuration__c> returnMap = new Map<String, RM_Configuration__c>();
        
        if(configMap == null || configMap.isEmpty()){
            return returnMap;
        }
        else{
            for(RM_Configuration__c configObj: configMap.values()){
                if(DeploymentControllerService.getRecordTypeIdByName(Label.RM_Configuration, Label.Jenkins_Job) == configObj.recordTypeId){
                    returnMap.put(configObj.Id, configObj);
                }
            }
        }
        return returnMap;
    }
    
    public static Map<String, RM_Configuration__c> fetchConfigData(){
        Map <String, Schema.SObjectType> schemaMap = Schema.getGlobalDescribe();
        Map <String, Schema.SObjectField> fieldMap = schemaMap.get(Label.RM_Configuration).getDescribe().fields.getMap();
        List<String> fieldList = new List<String>();
        fieldList.addAll(fieldMap.keySet());
        String fieldNames = String.join(fieldList, ',');
        System.debug('*** field Names *** '+fieldNames);
        String query = 'SELECT Target_Environment__r.Is_Production__c, Target_Environment__r.Salesforce_Password__c,';
        query += 'Target_Environment__r.Salesforce_URL__c, Target_Environment__r.SecurityToken__c, Target_Environment__r.User_Name__c, ';
        query += fieldNames+' from RM_Configuration__c';
        
        Map<String, RM_Configuration__c> returnMap = new Map<String, RM_Configuration__c>((List<RM_Configuration__c>)Database.query(query));
        
        return returnMap;
    }
    
    public PageReference saveConfig(){
        try{
            config.RecordTypeId = DeploymentControllerService.getRecordTypeIdByName(Label.RM_Configuration, Label.RM_Config) ;
            upsert config;
            readConfigData();
        }
        catch(Exception e){
            isError = true;
            errorMessage = e.getMessage();
        }
        return null;
    }
    
    public PageReference hideErrorPopup(){
        isError = false;
        return null;
    }
    
    public PageReference cancel(){
        jobsMap.clear();
        jobsMap = fetchConfigData(fetchConfigData());
        NoOfJobs = jobsMap.size();
        return null;
    }
    
    public PageReference createManualSteps(){
        manualStep = new Default_Step_Tracker_Records__c();
        Map<String, String> recTypeMap = DeploymentControllerService.getRecordTypeByObjectName(Label.Manual_Steps);
        recTypeId = '';
        recTypeList.clear();
        recTypeList.add(new SelectOption('', '-None-'));
        for(String s: recTypeMap.keySet()){
            recTypeList.add(new SelectOption(s, recTypeMap.get(s)));
        }
        showStepTrackers = true;
        fieldRequired = false;
        return null;
    }
    
    public PageReference cancelStepTrackers(){
        showStepTrackers = false;
        return null;
    }
    
    public PageReference saveStepTrackers(){
        if(String.isEmpty(manualStep.Name)){
            fieldRequired = true;
            return null;
        }
        else if(String.isEmpty(manualStep.Steps_to_perform__c)){
            fieldRequired = true;
            return null;
        }
        else if(String.isEmpty(manualStep.Component__c)){
            fieldRequired = true;
            return null;
        }
        else{
            try{
                System.debug('*** createForCurrentRelease *** '+createForCurrentRelease);
                insert manualStep;
                //If createForCurrentRelease = true, create manual steps for existing in-progress release records
                if(createForCurrentRelease == true){
                    List<Manual_steps_tracker__c> stepTrackerList = new List<Manual_steps_tracker__c>();
                    for(Release__c relObj: [select Id, (Select Id from Release_checklist__r) from Release__c 
                                            where Status__c =: Label.Yellow]){
                        for(Release_checklist__c chkList: relObj.Release_checklist__r){
                            Manual_steps_tracker__c stepTrackObj = new Manual_steps_tracker__c();
                            stepTrackObj.RecordTypeId = recTypeId;
                            stepTrackObj.Component__c = manualStep.Component__c;
                            stepTrackObj.Release_checklist__c = chkList.Id;
                            stepTrackObj.Steps_to_perform__c = manualStep.Steps_to_perform__c;
                            stepTrackObj.Prod_Applicable__c = manualStep.Prod_Applicable__c;
                            stepTrackObj.QA_Applicable__c = manualStep.QA_Applicable__c;
                            stepTrackObj.UAT_Applicable__c = manualStep.UAT_Applicable__c;
                            stepTrackerList.add(stepTrackObj);
                        }
                    }
                    
                    insert stepTrackerList;
                }
                
                defaultStepsList.clear();
                defaultStepsMap.clear();
                defaultStepsList = Default_Step_Tracker_Records__c.getAll().values();
                for(Default_Step_Tracker_Records__c step: defaultStepsList){
                    defaultStepsMap.put(step.Id, step);
                }
        
                showStepTrackers = false;
                return null;
            }
            catch(Exception e){
                isError = true;
                errorMessage = e.getMessage();
                return null;
            }
        }
    }
    
    public PageReference editJenkinsJobs(){
        String jobId = ApexPages.CurrentPage().getParameters().get('jobName');
        jenkinsJobsObj = jobsMap.get(jobId);
        showJenkinsJobs = true;
        fieldRequired = isError = false;
        errorMessage = '';
        return null;
    }
    
    public PageReference deleteJenkinsJobs(){
        String jobId = ApexPages.CurrentPage().getParameters().get('jobName');
        jenkinsJobsObj = jobsMap.get(jobId);
        delete jenkinsJobsObj;
        jobsMap.clear();
        jobsMap = fetchConfigData(fetchConfigData());
        NoOfJobs = jobsMap.size();
        return null;
    }
    
    public PageReference createJenkinsUser(){
        jenkinsUser = new RM_Configuration__c();
        showJenkinsUsers = true;
        fieldRequired = false;
        isError = false;
        deActiveUser = isActiveUser = false;
        errorMessage = '';
        return null;
    }
    
    public PageReference cancelJenkinsUser(){
        showJenkinsUsers = false;
        fieldRequired = false;
        isError = false;
        errorMessage = '';
        return null;
    }
    public Boolean isActiveUser{ get; set; }
    public Boolean deActiveUser{ get; set; }
    
    public PageReference saveJenkinsUsers(){
        isActiveUser = false;
        System.debug('*** inside saveJenkinsUsers *** ');
        createForCurrentRelease = false;
        if(String.isEmpty(jenkinsUser.Jenkins_User_Name__c)){
            fieldRequired = true;
            errorMessage = Label.Required_Field;
            isActiveUser = false;
            return null;
        }
        else if(checkExistingJenkinsUser(jenkinsUser.Jenkins_User_Name__c, jenkinsUser.SFDC_User__c)){
            fieldRequired = true;
            errorMessage = Label.Jenkins_User_Present;
            isActiveUser = false;
            return null;
        }
        else if(String.isEmpty(jenkinsUser.Jenkins_Password__c)){
            fieldRequired = true;
            errorMessage = Label.Required_Field;
            isActiveUser = false;
            return null;
        }
        else{
            try{
                jenkinsUser.RecordTypeId = DeploymentControllerService.getRecordTypeIdByName(Label.RM_Configuration, Label.Jenkins_Authentication) ;
                List<RM_Configuration__c> configUserList = [select Id, Jenkins_User_Name__c, Jenkins_User_Active__c from RM_Configuration__c 
                                                    where RecordTypeId =:jenkinsUser.RecordTypeId 
                                                    AND Jenkins_User_Active__c = TRUE
                                                    AND Jenkins_User_Name__c =: jenkinsUser.Jenkins_User_Name__c
                                                    AND SFDC_User__c =: jenkinsUser.SFDC_User__c];
                
                List<RM_Configuration__c> upsertList = new List<RM_Configuration__c>();                                    
                if(configUserList.isEmpty()){
                    insert jenkinsUser;
                    showJenkinsUsers = isError = false;
                    errorMessage = '';
                }
                else if(deActiveUser == true){
                    configUserList[0].Jenkins_User_Active__c = false;
                    upsertList.add(configUserList[0]);
                    upsertList.add(jenkinsUser);
                    upsert upsertList;
                    showJenkinsUsers = isError = false;
                    errorMessage = '';
                }
                else if(jenkinsUser.Jenkins_User_Active__c == false){
                    insert jenkinsUser;
                    showJenkinsUsers = isError = false;
                    errorMessage = '';
                }
                else{
                    isActiveUser = true;
                    isError = true;
                    errorMessage = Label.Another_Active_Jenkins_User+' '+configUserList[0].Jenkins_User_Name__c; //'Another user \"'+configUserList[0].Jenkins_User_Name__c+'\" is currently Active. ';
                }
                return null;
            }
            catch(Exception e){
                isError = true;
                errorMessage = e.getMessage();
                return null;
            }
        }
    }
    
    public Boolean checkExistingJenkinsUser(String userName, String sfUserId){
        List<RM_Configuration__c> configUserList = [select Id, Jenkins_User_Name__c, Jenkins_User_Active__c from RM_Configuration__c 
                                                    where Jenkins_User_Name__c =: userName
                                                    AND SFDC_User__c =: sfUserId];
        if(configUserList.isEmpty()){
            return false;
        }
        else{
            return true;
        }
    }
    public PageReference createJenkinsJobs(){
        jenkinsJobsObj = new RM_Configuration__c();
        showJenkinsJobs = true;
        fieldRequired = false;
        showJenkinsUsers = false;
        if(jenkinsUsersList != null)
            jenkinsUsersList.clear();
        isError = false;
        errorMessage = '';
        return null;
    }
    
    public PageReference cancelJenkinsJobs(){
        showJenkinsJobs = false;
        showJenkinsUsers = false;
        return null;
    }
    
    public String errorType{ get; set; }
    
    public PageReference saveJenkinsJobs(){
        fieldRequired = isError = showJenkinsUsers = false;
        errorMessage = '';
        if(String.isBlank(jenkinsJobsObj.Job_Name__c)){
            fieldRequired = true;
            errorMessage = Label.Required_Field;
            return null;
        }
        else if(String.isBlank(jenkinsJobsObj.Job_Type__c)){
            fieldRequired = true;
            errorMessage = Label.Required_Field;
            return null;
        }
        else if(String.isBlank(jenkinsJobsObj.Source_Org__c)){
            fieldRequired = true;
            errorMessage = Label.Required_Field;
            return null;
        }
        else if(String.isBlank(jenkinsJobsObj.Target_Environment__c)){
            fieldRequired = true;
            errorMessage = Label.Required_Field;
            return null;
        }
        else if(String.isBlank(jenkinsJobsObj.Job_Token__c)){
            fieldRequired = true;
            errorMessage = Label.Required_Field;
            return null;
        }
        else if(String.isBlank(jenkinsJobsObj.Package_To_Validate__c)){
            fieldRequired = true;
            errorMessage = Label.Required_Field;
            return null;
        }
        else if(String.isBlank(jenkinsJobsObj.Jenkins_Job_Name__c)){
            fieldRequired = true;
            errorMessage = Label.Required_Field;
            return null;
        }
        else if(String.isBlank(jenkinsJobsObj.Job_URL__c)){
            fieldRequired = true;
            errorMessage = Label.Required_Field;
            return null;
        }
        else if(!validate(jenkinsJobsObj.Job_URL__c, urlRegex)){
            isError = true;
            errorMessage = Label.Invalid_URL;
            errorType = Label.Job_URL_Error; //'jobURL';
            return null;
        }
        else if(String.isBlank(jenkinsJobsObj.Pipeline_URL__c)){
            fieldRequired = true;
            errorMessage = Label.Required_Field;
            return null;
        }
        else if(!validate(jenkinsJobsObj.Pipeline_URL__c, urlRegex)){
            isError = true;
            errorMessage = Label.Invalid_URL;
            errorType = Label.Pipeline_URL_Error; //'pipelineURL';
            return null;
        }
        else if(!validate(jenkinsJobsObj.On_Demand_Validation_Job_URL__c, urlRegex)){
            isError = true;
            errorMessage = Label.Invalid_URL;
            errorType = Label.On_Demand_URL_Error; //'onDemandUrl';
            return null;
        }
        else if(!String.isBlank(jenkinsJobsObj.On_Demand_Validation_Job_URL__c) && String.isBlank(jenkinsJobsObj.On_Demand_Job_Token__c)){
            isError = true;
            errorMessage = Label.Token_Required;
            errorType = Label.On_Demand_Token_Error; //'onDemandUrl';
            return null;
        }
        else{
            try{
                fieldRequired = isError = false;
                errorMessage = '';
                jenkinsJobsObj.recordTypeId = DeploymentControllerService.getRecordTypeIdByName(Label.RM_Configuration, Label.Jenkins_Job);
                upsert jenkinsJobsObj;
                showJenkinsJobs = false;
                jobsMap.clear();
                jobsMap = fetchConfigData(fetchConfigData());
                NoOfJobs = jobsMap.size();
                return null;
            }
            catch(Exception e){
                isError = true;
                errorMessage = e.getMessage();
                return null;
            }
        }
        return null;
    }
    
    public static Boolean validate(String stringToValidate, String regex) {
        if(String.isBlank(stringToValidate)){
            return true;
        }
        
        Pattern emailPattern = Pattern.compile(regex);
        Matcher emailMatcher = emailPattern.matcher(stringToValidate);
    
        if (emailMatcher.matches()) 
            return true;
        else
        return false;    
    }
    
    
    public PageReference readJenkinsUsers(){
        showJenkinsUsers = false;
        jenkinsUsersList = new List<RM_Configuration__c>();
        jenkinsUsersList = [select Id, Jenkins_User_Name__c, Jenkins_User_Active__c, SFDC_User__c, SFDC_User__r.Name  
                            from RM_Configuration__c 
                            where RecordTypeId =:DeploymentControllerService.getRecordTypeIdByName(Label.RM_Configuration, Label.Jenkins_Authentication)  
                            ];
        return null;
    }
    
    public PageReference updateJenkinsUsers(){
        Integer cnt = 0;
        isError = false;
        errorMessage = '';
        showJenkinsUsers = false;
        /*for(RM_Configuration__c user: jenkinsUsersList){
            if(user.Jenkins_User_Active__c == true){
                cnt++;
            }
            if(cnt>1){
                isError = true;
                errorMessage = Label.Active_Jenkins_User;
                break;
            }
        }*/
        //if(!isError){
            update jenkinsUsersList;
            jenkinsUsersList.clear();
        //}
        return null;
    }
    
    public PageReference cancelJenkinsUsers(){
        isError = false;
        errorMessage = '';
        jenkinsUsersList.clear();
        return null;
    }
    
    public PageReference editManualStep(){
        String stepId = ApexPages.CurrentPage().getParameters().get('stepId');
        manualStep = defaultStepsMap.get(stepId);
        showStepTrackers = true;
        fieldRequired = isError = false;
        errorMessage = '';
        return null;
    }
    
    public PageReference deleteManualStep(){
        System.debug('*** inside deleteManualStep *** '+defaultStepsList.size());
        String stepId = ApexPages.CurrentPage().getParameters().get('stepId');
        manualStep = defaultStepsMap.get(stepId);
        System.debug('*** manualStep *** '+manualStep );
        delete manualStep;
        defaultStepsList.clear();
        defaultStepsMap.clear();
        defaultStepsList = Default_Step_Tracker_Records__c.getAll().values();
        for(Default_Step_Tracker_Records__c step: defaultStepsList){
            defaultStepsMap.put(step.Id, step);
        }
        System.debug('*** After deleteManualStep *** '+defaultStepsList.size());
        return null;
    }
    
    
}