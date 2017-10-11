public class DeploymentControllerService{
    //Variable
    public LIst<Deployment_Stage__c> stagesList{ get; set; }
    public DeploymentControllerService(){
        stagesList = new List<Deployment_Stage__c>();
    }
    public static Map<String, String> stageNameMap{ get; set; }
    static{
        stageNameMap = new Map<String, String>();
         //LOGIC ADD BY MUTHU ON 21/04/2017, REPLACE LOGIC FROM CUSTOM SETTING TO CUSTOM METADATA 
         //START 
        /*Map<String, Stages__c> stageDataMap = Stages__c.getAll();
        for(Stages__c s: stageDataMap.values()){
            stageNameMap.put(s.Name, s.Stage_Name__c);
        }
        */
        map<string,RM_Stages__mdt> stageMap=RM_Util.getRM_StageValue();
           for( RM_Stages__mdt rmm : stageMap.Values()){
                  stageNameMap.put(rmm.Label, rmm.Stage_Name__c);   

           }
        //END 
    }    
    public void createJobs(String url, Integer stageLevel, Integer stageOrder, RM_Configuration__c config){
        Http http = new Http();
        HTTPRequest req = new HTTPRequest();
        if(!url.endsWith('/api/json?pretty=true')){
            url = url + '/api/json?pretty=true';
        }
        
        Integer endInd = url.indexOf('/jenkins');
        String domainNameToReplace = url.subString(0, endInd);
        req.setEndpoint(url);
        
        Blob headerValue = Blob.valueOf(config.Jenkins_User_Name__c+ ':' + config.Jenkins_Password__c);
        String authorizationHeader = 'Basic ' + EncodingUtil.base64Encode(headerValue);
        
        system.debug(authorizationHeader);
        req.setHeader('Authorization', authorizationHeader);
        //req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
        req.setMethod('GET');
        
        HTTPResponse resp = http.send(req);
        system.debug('*** Response *** '+resp);
        String body = resp.getBody();
        body = body.replaceAll('number', 'buildNumber');
        JenkinsJobDetails details = (JenkinsJobDetails)JSON.deserialize(body, JenkinsJobDetails.class);
        System.debug('*** details *** '+details);
        
        Deployment_Stage__c stageObj = new Deployment_Stage__c();
        stageObj.Name = details.name.toLowerCase();
        
        //LOGIC ADD BY MUTHU ON 21/04/2017, REPLACE LOGIC FROM CUSTOM SETTING TO CUSTOM METADATA 
         //START 
        
        /*Map<String, Stages__c> stageDataMap = Stages__c.getAll();
        for(Stages__c s: stageDataMap.values()){
            if(details.Name.containsIgnoreCase(s.Name)){
                stageObj.Stage_Label__c = s.Stage_Name__c;
            }
        }
        */
         map<string,RM_Stages__mdt> stageMap=RM_Util.getRM_StageValue();
           for( RM_Stages__mdt rmm : stageMap.Values()){
                 if(details.Name.containsIgnoreCase(rmm.Label)){
                    stageObj.Stage_Label__c = rmm.Stage_Name__c;
                 }
           }
        //END 
        
        //stageNameMap.keySet().contains
        //stageObj.Deployment__c = deploymentId;
        stageObj.Stage_Level__c = stageLevel;
        stageObj.Order__c = stageOrder;
        stageObj.Build_Number__c = (details.builds == null)?1:((details.builds.isEmpty())?1:(details.builds[0].buildNumber+1));
        stageObj.Status__c = 'Pending'; //getStatus(details.color, details.inQueue);
        //stageObj.Stage_URL__c = details.url.replace('52.31.230.50', '52.50.53.136');
        String domainNameFromServer = details.url.subString(0, details.url.indexOf('/jenkins'));
        System.debug('*** strTmp *** '+domainNameFromServer);
        System.debug('*** urlTmp *** '+domainNameToReplace);
        stageObj.Stage_URL__c = details.url.replace(domainNameFromServer, domainNameToReplace);       
        stagesList.add(stageObj);
        //insert stagesList;
        
        Integer cnt = 0;
        if(details.downstreamProjects != null){
            for(JenkinsJobDetails.downstreamProjects prj: details.downstreamProjects){
                if(cnt == 0){
                    stageOrder = stageOrder;
                }
                else{
                    stageOrder = stageOrder + 1;
                }
                cnt++;
                String domainNameFromServerNJ = prj.url.subString(0, prj.url.indexOf('/jenkins'));
                System.debug('*** strTmp *** '+domainNameFromServerNJ);
                System.debug('*** urlTmp *** '+domainNameToReplace);
                String newJobUrl = prj.url.replace(domainNameFromServerNJ, domainNameToReplace);
                createJobs(newJobUrl, stageLevel+1, stageOrder, config);
            }
        }
    }
    
    public static JenkinsJobDetails.JobStatus viewJobStatus(String url, RM_Configuration__c config){
        Http http = new Http();
        HTTPRequest req = new HTTPRequest();
        System.debug('*** URL *** '+url);
        /*if(String.isEmpty(url)){
            url = 'http://52.48.51.211/jenkins/job/FSDemo_CR/job/FSDemo_CR_pre_deploy_validation/api/json?pretty=true';
        }
        else{
            url = url.replace('52.31.230.50', '52.48.51.211');
            //url = url+'/api/json?pretty=true';
        }*/
        req.setEndpoint(url);
        
        Blob headerValue = Blob.valueOf(config.Jenkins_User_Name__c+ ':' + config.Jenkins_Password__c);
        String authorizationHeader = 'Basic ' + EncodingUtil.base64Encode(headerValue);
        
        system.debug(authorizationHeader);
        req.setHeader('Authorization', authorizationHeader);
        //req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
        req.setMethod('GET');
        HttpResponse resp = new HttpResponse();
        if(test.isRunningTest()){
          // resp = new HttpResponse();
            String usermember = '{'+'"actions" : ['+'{"causes" : ['+'{"shortDescription" : "Started by user p.rameshwar.wayal",'+'"userId" : "p.rameshwar.wayal",'+'"userName" : "p.rameshwar.wayal"'+'}'
                                +']'+'},'+'{'+'},'+'{'+'},'+'{'+'"buildsByBranchName" : {'+'"refs/remotes/RM/develop" : {'+'"buildNumber" : 251,'+'"buildResult" : null,'
                                +'"marked" : {'+'"SHA1" : "a73d894ba63065ac75f13a41dca4175d7815d1ad",'+'"branch" : '+'['+'{'+'"SHA1" : "a73d894ba63065ac75f13a41dca4175d7815d1ad",'
                                +'"name" : "refs/remotes/RM/develop"}'+']'+'},'+'"revision" : {'+'"SHA1" : "a73d894ba63065ac75f13a41dca4175d7815d1ad",'+'"branch" : ['
                                +'{'+'"SHA1" : "a73d894ba63065ac75f13a41dca4175d7815d1ad",'+'"name" : "refs/remotes/RM/develop"}'+']}}},'+'"lastBuiltRevision" : {'
                                +'"SHA1" : "a73d894ba63065ac75f13a41dca4175d7815d1ad",'+'"branch" : [{'+'"SHA1" : "a73d894ba63065ac75f13a41dca4175d7815d1ad",'
                                +'"name" : "refs/remotes/RM/develop"'+'}]},'+'"remoteUrls" : ['+'"ssh://jenkins@gerrit.service.adop.consul:29418/Prashant_DX_Demo"'+'],'
                                +'    "scmName" : ""'+'},'+'{},'+'{},'+'{'+'"parameters" :'+'[{"name" : "T",'+'"value" : "p.rameshwar.wayal<br/>Updated scratch org fileChange-Id: If482411cff58e3123e582884ac088e6c16dd366e"'+'},'
                                +'{"name" : "B",'+'"value" : "251"'+'}]},'+'{},'+'{},'+'{},'+'{'+'},'+'{}],'+'"artifacts" : '+'[{"displayPath" : null,'+'"fileName" : "build.xml",'
                                +'"relativePath" : "Deploy/build.xml"},'+'{"displayPath" : null,'+'"fileName" : "deploy.bat",'+'"relativePath" : "Deploy/deploy.bat"},'+'{"displayPath" : null,'+'"fileName" : "package.xml",'
                                +'"relativePath" : "Deploy/dist/package.xml"},'+'{"displayPath" : null,'+'"fileName" : "download_jars.xml",'+'"relativePath" : "Deploy/download_jars.xml"},'+'{"displayPath" : null,'
                                +'"fileName" : "generate_package_xml.sh",'+'"relativePath" : "Deploy/generate_package_xml.sh"},'+'{"displayPath" : null,'+'"fileName" : "package.xml",'
                                +'"relativePath" : "Deploy/package.xml"'+'},'+'{"displayPath" : null,'+'"fileName" : "validate.bat",'+'"relativePath" : "Deploy/validate.bat"'+'},'+'{"displayPath" : null,'
                                +'"fileName" : ".project",'+'"relativePath" : "dxdemo/.project"},'+'{"displayPath" : null,'+'"fileName" : "workspace-scratch-def.json",'+'"relativePath" : "dxdemo/config/workspace-scratch-def.json"'+'},'
                                +'{"displayPath" : null,'+'"fileName" : "SalesforceDXDemoController.cls",'+'"relativePath" : "dxdemo/force-app/main/default/classes/SalesforceDXDemoController.cls"'+'},'+'{"displayPath" : null,'
                                +'"fileName" : "SalesforceDXDemoController.cls-meta.xml",'+'"relativePath" : "dxdemo/force-app/main/default/classes/SalesforceDXDemoController.cls-meta.xml"},'
                                +'{"displayPath" : null,"fileName" : "SalesforceDXDemo.page","relativePath" : "dxdemo/force-app/main/default/pages/SalesforceDXDemo.page"},'+'{"displayPath" : null,'
                                +'"fileName" : "SalesforceDXDemo.page-meta.xml",'+'"relativePath" : "dxdemo/force-app/main/default/pages/SalesforceDXDemo.page-meta.xml"},'+'{'+'"displayPath" : null,'
                                +'"fileName" : "package.xml",'+'"relativePath" : "dxdemo/force-app/package.xml"'+'},'+'{'+'"displayPath" : null,'+'"fileName" : "version.txt",'+'"relativePath" : "dxdemo/force-app/version.txt"},'
                                +'{"displayPath" : null,'+'"fileName" : "README.md",'+'"relativePath" : "dxdemo/README.md"},'+'{'+'"displayPath" : null,'+'"fileName" : "sfdx-workspace.json",'+'"relativePath" : "dxdemo/sfdx-workspace.json"'+'},'
                                +'{'+'"displayPath" : null,'+'"fileName" : "build.gradle",'+'"relativePath" : "groovy/build.gradle"},'+'{'+'"displayPath" : null,'+'"fileName" : "GitHubController.groovy",'
                                +'"relativePath" : "groovy/src/main/groovy/GitHubController.groovy"},'+'{'+'"displayPath" : null,'+'"fileName" : "PackageManager.groovy",'+'"relativePath" : "groovy/src/main/groovy/PackageManager.groovy"},'
                                +'{"displayPath" : null,'+'"fileName" : "version.txt",'+'"relativePath" : "version.txt"}],'+'"building" : false,'+'"description" : null,'+'"displayName" : "#251",'+'"duration" : 49162,'
                                +'"estimatedDuration" : 33386,'+'"executor" : null,'+'"fullDisplayName" : "Prashant_RM » Prashant_RM » RM_pre_deploy_validation #251",'+'"id" : "251",'+'"keepLog" : false,'+'"number" : 251,'
                                +'"queueId" : 5598,'+'"result" : "SUCCESS",'+'"timestamp" : 1490181288678,'+'"url" : "http://52.50.53.136/jenkins/job/Prashant_RM/job/Prashant_RM/job/RM_pre_deploy_validation/251/",'+'"builtOn" : "",'
                                +'"changeSet" : {'+'"items" : [],'+'"kind" : "git"},'+'"culprits" : []}';         
             System.debug('*** usermember *** '+usermember);
             resp.setHeader('Content-Type', 'application/json');
             resp.setStatusCode(200);
             resp.setBody(usermember);
             resp.setStatus('Success');
            } else{
                     resp = http.send(req);
            }
       // HTTPResponse resp = http.send(req);
        system.debug('*** Response *** '+resp);
        if(resp.getStatusCode() == 200){
            String body = resp.getBody();
            body=body.trim();
            body = body.replaceFirst('��', '');
            System.debug('*** body *** '+body);
            //body = body.replaceAll('number', 'buildNumber');
            JenkinsJobDetails.JobStatus status = (JenkinsJobDetails.JobStatus)JSON.deserialize(body, JenkinsJobDetails.JobStatus.class);
            System.debug('*** status *** '+status);
            return status;
        }
        else if(resp.getStatusCode() == 404){
            JenkinsJobDetails.JobStatus status = new JenkinsJobDetails.JobStatus();
            status.result = 'Pending';
            status.building = false;
            return status;
        }
        return null;
    }
    
    public static String getStatus(String status, Boolean building){
        if(status == null && building == true){
            return 'In Progress';
        }
        else{
            if(status == null && building == true){
                return 'In Progress';
            }
            else if(status.equals('SUCCESS')){
                return 'Success';
            }
            else if(status.equals('FAILURE')){
                return 'Failure';
            }
            else if(status.equals('ABORTED')){
                return 'Aborted';
            }
            else{
                return 'Pending';
            }
        }
        return 'Pending';
    }
    
    @future
    public static void createArtifactFile(String jobId, String statusString){
        System.debug('*** statusString *** '+statusString);
        Attachment at = new Attachment();
        at.Name = 'artifact.txt';
        at.ContentType = 'text/plain';
        at.Body = Blob.valueOf(statusString);
        at.ParentId = jobId;
        insert at;
    }
    
    public static Map<String, Map<String, List<String>>> createArtifactData(String data){
        Map<String, Map<String, List<String>>> artifactMap = new Map<String, Map<String, List<String>>>();
        Map<String, List<String>> fileMap = new Map<String, List<String>>();
        String packageFile = '';
        System.debug('*** data *** '+data);
        
        
        JenkinsJobDetails.ArtifactDetails jobStatus = (JenkinsJobDetails.ArtifactDetails)JSON.deserialize(data, JenkinsJobDetails.ArtifactDetails.class);
        List<JenkinsJobDetails.artifacts> artifactList = new List<JenkinsJobDetails.artifacts>();
        if(jobStatus == null || jobStatus.artifacts == null){
            return artifactMap;
        }
        for(JenkinsJobDetails.artifacts artifact: jobStatus.artifacts){
            if(artifact.relativePath.contains('dist')){
                String str = artifact.relativePath.subString(artifact.relativePath.indexOf('dist'), artifact.relativePath.length());
                System.debug('*** str *** '+str);
                List<String> dataList = str.split('/');
                if(fileMap.containsKey(dataList[1])){
                    fileMap.get(dataList[1]).add(dataList[2]);
                }
                else{
                    if(dataList.size() == 3){
                        fileMap.put(dataList[1], new List<String>{dataList[2]});
                    }
                    else{
                        packageFile = 'z_'+dataList[1];
                    }
                }
            } 
        }
        fileMap.put(packageFile, new List<String>());
        artifactMap.put('src', fileMap);
        return artifactMap;
    }
    
    public static String getRecordTypeIdByName(String objectAPIName, String recTypeName){
        String recordTypeId = '';
        System.debug('*** objectAPIName *** '+objectAPIName+' *** recTypeName *** '+recTypeName);
        Schema.DescribeSObjectResult sobjectResult = Schema.getGlobalDescribe().get(objectAPIName).getDescribe();
        List<Schema.RecordTypeInfo> recordTypeInfo = sobjectResult.getRecordTypeInfos();
        Map<String,Id> mapofCaseRecordTypeNameandId = new Map<String,Id>();
        for(Schema.RecordTypeInfo info : recordTypeInfo){
            System.debug('*** info  *** '+info);
            if(recTypeName.equals(info.getName())){
                recordTypeId = info.getRecordTypeId();
                break;
            }
        }
        System.debug('*** recordTypeId *** '+recordTypeId);
        return recordTypeId;
    }
    
    public static Map<String, String> getRecordTypeByObjectName(String objectAPIName){
        Map<String, String> recTypeMap = new Map<String, String>();
        System.debug('*** objectAPIName *** '+objectAPIName);
        Schema.DescribeSObjectResult sobjectResult = Schema.getGlobalDescribe().get(objectAPIName).getDescribe();
        List<Schema.RecordTypeInfo> recordTypeInfo = sobjectResult.getRecordTypeInfos();
        Map<String,Id> mapofCaseRecordTypeNameandId = new Map<String,Id>();
        for(Schema.RecordTypeInfo info : recordTypeInfo){
            System.debug('*** info  *** '+info);
            recTypeMap.put(info.getRecordTypeId(), info.getName());
            /*if(recTypeName.equals(info.getName())){
                recordTypeId = info.getRecordTypeId();
                break;
            }*/
        }
        System.debug('*** recordTypeId *** '+recTypeMap);
        return recTypeMap;
    }
    
    public static String triggerOnDemandValidationJob(RM_Configuration__C jenkinsJob, RM_Configuration__C config){
        String status = '';
        try{
            
            Http http = new Http();
            HTTPRequest req = new HTTPRequest();
            String parameters = formatParameters(jenkinsJob);
            req.setEndpoint(jenkinsJob.On_Demand_Validation_Job_URL__c+'/buildWithParameters?token='+jenkinsJob.On_Demand_Job_Token__c+'&'+parameters+'&.crumb=5e9a47d3d38ac4ef948afc56345eaae8');
            system.debug('******Testing'+jenkinsJob.On_Demand_Validation_Job_URL__c+'/buildWithParameters?token='+jenkinsJob.On_Demand_Job_Token__c+'&'+parameters);
            Blob headerValue = Blob.valueOf(config.Jenkins_User_Name__c+ ':' + config.Jenkins_Password__c);
            String authorizationHeader = 'Basic ' + EncodingUtil.base64Encode(headerValue);
            //+'&.crumb=5e9a47d3d38ac4ef948afc56345eaae8'
            system.debug(authorizationHeader);
            //req.setHeader('.crumb', '5e9a47d3d38ac4ef948afc56345eaae8');
            req.setHeader('Authorization', authorizationHeader);
            req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
            req.setMethod('POST');
            
            HTTPResponse resp = http.send(req);
            system.debug('*** Response *** '+resp);
            String body = resp.getBody();
            
            if(resp.getstatuscode() == 201){
                JenkinsJobDetails details = viewJobStatus(jenkinsJob, config);
                status = 'SUCCESS:'+((details.builds.isEmpty())?1:(details.builds[0].buildNumber+1));
            }
            else{
                status = 'ERROR: '+resp.getStatus();
            }
        }catch(Exception e){
            status = 'ERROR: '+e.getMessage();
        }
        return status;
    }
    
    public static String formatParameters(RM_Configuration__C jenkinsJob){
        String parameters = 'SALESFORCE_PASSWORD='+jenkinsJob.Target_Environment__r.Salesforce_Password__c;//+jenkinsJob.Target_Environment__r.SecurityToken__c;
        parameters += '&SALESFORCE_TOKEN='+jenkinsJob.Target_Environment__r.SecurityToken__c;
        parameters += '&PACKAGE_TO_VALIDATE='+jenkinsJob.Package_To_Validate__c;
        parameters += '&SALESFORCE_URL='+jenkinsJob.Target_Environment__r.Salesforce_URL__c;
        parameters += '&SALESFORCE_USERNAME='+jenkinsJob.Target_Environment__r.User_Name__c;
        
        return parameters;
    }
    
    public static JenkinsJobDetails viewJobStatus(RM_Configuration__C jenkinsJob, RM_Configuration__C config){
        Http http = new Http();
        HTTPRequest req = new HTTPRequest();
        req.setEndpoint(jenkinsJob.On_Demand_Validation_Job_URL__c+'/api/json?pretty=true'+'&.crumb=5e9a47d3d38ac4ef948afc56345eaae8');
        
        Blob headerValue = Blob.valueOf(config.Jenkins_User_Name__c+ ':' + config.Jenkins_Password__c);
        String authorizationHeader = 'Basic ' + EncodingUtil.base64Encode(headerValue);
        
        system.debug(authorizationHeader);
        req.setHeader('Authorization', authorizationHeader);
        req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
        req.setMethod('POST');
        
        HTTPResponse resp = http.send(req);
        system.debug('*** Response *** '+resp);
        String body = resp.getBody();
        body=body.trim();
        body = body.replaceFirst('��', '');
        system.debug('*** body *** '+body);
        body = body.replaceAll('number', 'buildNumber');
        JenkinsJobDetails details = (JenkinsJobDetails)JSON.deserialize(body, JenkinsJobDetails.class);
        System.debug('*** details *** '+details);
        return details;
    }
    
    public static Release__c fetchReleaseRecord(String releaseId){
        return [select Id,OwnerId,Owner.Name,User__c, Name,Approval_Status__c,RecordType.name,
                            Deployment_Approval_Required__c,On_Demand_Validation_Needed__c, Release_Start_Date__c, 
                            Release_Planned_End_Date__c, Production_Deploy_Approved__c,
                            Prod_Validation_Complete__c from Release__c 
                            where Id=: releaseId];
    }
    
    public static String replaceURLs(String strToReplace, List<Attachment> attachmentList){
        String updatedString = strToReplace;
        Pattern myPattern = Pattern.compile('<td>(.*?)</td>');
        Pattern myPattern1 = Pattern.compile('<a (.*?)</a>');
        Matcher m = myPattern.matcher(updatedString);
        Map<String, Attachment> attachMap = new Map<String, Attachment>();
        for(Attachment a: attachmentList){
            attachMap.put(a.Name, a);
        }
        String replacedString = '';
        while(m.find())
        {
            String tdContent = m.group();
            Matcher m1 = myPattern1.matcher(tdContent);
            String updatedTDContent = '';
            if(m1.find()){
                String linkContent = m1.group();
                Integer strtind = linkContent.indexOf('.');
                Integer endInd = linkContent.indexOf('>');
                
                String url = linkContent.SubString(strtInd, endInd-1);
                String fileName = linkContent.SubString(strtInd+2, endInd-1);
                if(attachMap.keySet().contains(fileName)){
                    updatedTDContent = linkContent.replace(url, '/apex/showLog?docId='+attachMap.get(fileName).id);
                }
                updatedTDContent = updatedTDContent.replaceFirst('>', ' target="_blank" >');
                replacedString = tdContent.replace(linkContent, updatedTDContent);
                updatedString = updatedString.replace(tdContent, replacedString);
            }
        }
        system.debug('*** updatedString *** '+updatedString);
        return updatedString;
    }
    
    public static void updateDeploymentActivities(String targetEnvironmentId, String checklistId){
        List<Manual_Steps_Environments__c> manualStepsList = new List<Manual_Steps_Environments__c>();
        for(Manual_Steps_Environments__c mse: [Select Id, Is_Completed__c from Manual_Steps_Environments__c 
                                                where Manual_Steps__r.Release_checklist__c =: checklistId
                                                AND SF_Environment__c =: targetEnvironmentId]){
            mse.Is_Completed__c = false;
            manualStepsList.add(mse);
        }
        
        if(!manualStepsList.isEmpty()){
            update manualStepsList;
        }
    }
}