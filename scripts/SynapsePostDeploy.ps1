param(
  [string] $NetworkIsolationMode,
  [string] $SubscriptionID,
  [string] $ResourceGroupName,
  [string] $ResourceGroupLocation,
  [string] $SynapseWorkspaceName,
  [string] $SynapseWorkspaceID,
  [string] $KeyVaultName,
  [string] $KeyVaultID,
  [string] $WorkspaceDataLakeAccountName,
  [string] $WorkspaceDataLakeAccountID,
  [string] $RawDataLakeAccountName,
  [string] $RawDataLakeAccountID,
  [string] $CuratedDataLakeAccountName,
  [string] $CuratedDataLakeAccountID,
  [string] $UAMIIdentityID,
  [Parameter(Mandatory = $false)]
  [bool] $CtrlDeployAI,
  [AllowEmptyString()]
  [Parameter(Mandatory = $false)]
  [string] $AzMLSynapseLinkedServiceIdentityID,
  [AllowEmptyString()]
  [Parameter(Mandatory = $false)]
  [string] $AzMLWorkspaceName,
  [AllowEmptyString()]
  [Parameter(Mandatory = $false)]
  [string] $TextAnalyticsAccountID,
  [AllowEmptyString()]
  [Parameter(Mandatory = $false)]
  [string] $TextAnalyticsAccountName,
  [AllowEmptyString()]
  [Parameter(Mandatory = $false)]
  [string] $TextAnalyticsEndpoint,
  [AllowEmptyString()]
  [Parameter(Mandatory = $false)]
  [string] $AnomalyDetectorAccountID,
  [AllowEmptyString()]
  [Parameter(Mandatory = $false)]
  [string] $AnomalyDetectorAccountName,
  [AllowEmptyString()]
  [Parameter(Mandatory = $false)]
  [string] $AnomalyDetectorEndpoint,
  [Parameter(Mandatory = $false)]
  [bool] $CtrlDeployCosmosDB,
  [AllowEmptyString()]
  [Parameter(Mandatory = $false)]
  [string] $CosmosDBAccountID,
  [AllowEmptyString()]
  [Parameter(Mandatory = $false)]
  [string] $CosmosDBAccountName,
  [AllowEmptyString()]
  [Parameter(Mandatory = $false)]
  [string] $CosmosDBDatabaseName,
  [Parameter(Mandatory = $false)]
  [bool] $CtrlDeploySampleArtifacts,
  [AllowEmptyString()]
  [Parameter(Mandatory = $false)]
  [string] $SampleArtifactCollectioName
)


#------------------------------------------------------------------------------------------------------------
# FUNCTION DEFINITIONS
#------------------------------------------------------------------------------------------------------------
function Set-SynapseControlPlaneOperation {
  param (
    [string] $SynapseWorkspaceID,
    [string] $HttpRequestBody
  )
  
  $uri = "https://management.azure.com$SynapseWorkspaceID`?api-version=2021-06-01"
  $token = (Get-AzAccessToken -Resource "https://management.azure.com").Token
  $headers = @{ Authorization = "Bearer $token" }

  $retrycount = 1
  $completed = $false
  $secondsDelay = 60

  while (-not $completed) {
    try {
      Invoke-RestMethod -Method Patch -ContentType "application/json" -Uri $uri -Headers $headers -Body $HttpRequestBody -ErrorAction Stop
      Write-Host "Control plane operation completed successfully."
      $completed = $true
    }
    catch {
      if ($retrycount -ge $retries) {
        Write-Host "Control plane operation failed the maximum number of $retryCount times."
        Write-Warning $Error[0]
        throw
      }
      else {
        Write-Host "Control plane operation failed $retryCount time(s). Retrying in $secondsDelay seconds."
        Write-Warning $Error[0]
        Start-Sleep $secondsDelay
        $retrycount++
      }
    }
  }
}

function Save-SynapseLinkedService {
  param (
    [string] $SynapseWorkspaceName,
    [string] $LinkedServiceName,
    [string] $LinkedServiceRequestBody
  )

  [string] $uri = "https://$SynapseWorkspaceName.dev.azuresynapse.net/linkedservices/$LinkedServiceName"
  $uri += "?api-version=2019-06-01-preview"

  Write-Host "Creating Linked Service [$LinkedServiceName]..."
  $retrycount = 1
  $completed = $false
  $secondsDelay = 60

  while (-not $completed) {
    try {
      Invoke-RestMethod -Method Put -ContentType "application/json" -Uri $uri -Headers $headers -Body $LinkedServiceRequestBody -ErrorAction Stop
      Write-Host "Linked service [$LinkedServiceName] created successfully."
      $completed = $true
    }
    catch {
      if ($retrycount -ge $retries) {
        Write-Host "Linked service [$LinkedServiceName] creation failed the maximum number of $retryCount times."
        Write-Warning $Error[0]
        throw
      }
      else {
        Write-Host "Linked service [$LinkedServiceName] creation failed $retryCount time(s). Retrying in $secondsDelay seconds."
        Write-Warning $Error[0]
        Start-Sleep $secondsDelay
        $retrycount++
      }
    }
  }
}

function Save-SynapseSampleArtifacts {
  param (
    [string] $SynapseWorkspaceName,
    [string] $SampleArtifactCollectionName
  )

  #Install Synapse PowerShell Module
  if (Get-Module -ListAvailable -Name "Az.Synapse") {
    Write-Host "PowerShell Module Az.Synapse already installed."
  } 
  else {
    Install-Module Az.Synapse -Force
    Import-Module Az.Synapse
    Install-Module Az.MachineLearningServices -Force
    Import-Module Az.MachineLearningServices
      
  }
  #Install MachineLearningServices Module
  if (Get-Module -ListAvailable -Name "Az.MachineLearningServices") {
    Write-Host "PowerShell Module Az.MachineLearningServices already installed."
  } 
  else {
     
    # Install-Module Az.MachineLearningServices -Force
    # Import-Module Az.MachineLearningServices
      
  }

  #Add System.Web type to encode/decode URL
  Add-Type -AssemblyName System.Web

  #Authenticate for REST API calls
  $token = (Get-AzAccessToken -Resource "https://dev.azuresynapse.net").Token
  $headers = @{ Authorization = "Bearer $token" }

  $synapseTokens = @{"`#`#azsynapsewks`#`#" = $SynapseWorkspaceName; }
  $indexFileUrl = "https://raw.githubusercontent.com/CSALabsAutomation/azure-synapse-labs/main/environments/env1/Sample/index.json"
  $sampleCodeIndex = Invoke-WebRequest $indexFileUrl | ConvertFrom-Json

  foreach ($sampleArtifactCollection in $sampleCodeIndex) {
    if ($sampleArtifactCollection.template -eq $SampleArtifactCollectionName) {
      Write-Host "Deploying Sample Artifact Collection: $($sampleArtifactCollection.template)"
      Write-Host "-----------------------------------------------------------------------"

      #Create SQL Script artifacts.
      Write-Host "Deploying SQL Scripts:"
      Write-Host "-----------------------------------------------------------------------"
      foreach ($sqlScript in $sampleArtifactCollection.artifacts.sqlScripts) {
        $fileContent = Invoke-WebRequest $sqlScript.definitionFilePath

        if ($sqlScript.tokens.length -gt 0) {
          foreach ($token in $sqlScript.tokens) {
            $fileContent = $fileContent -replace $token, $synapseTokens.Get_Item($token)
          }
        }

        if ($sqlScript.interface.ToLower() -eq "powershell") {
          Write-Host "Creating SQL Script: $($sqlScript.name) via PowerShell"
          $definitionFilePath = [guid]::NewGuid()
          Set-Content -Path $definitionFilePath $fileContent
          Set-AzSynapseSqlScript -WorkspaceName $SynapseWorkspaceName -Name $sqlScript.name -DefinitionFile $definitionFilePath -FolderPath $sqlScript.workspaceFolderPath
          Remove-Item -Path $definitionFilePath    
        }
        elseif ($sqlScript.interface.ToLower() -eq "rest") {
          Write-Host "Creating SQL Script: $($sqlScript.name) via REST API"
          $subresource = "sqlScripts"
          $uri = "https://$SynapseWorkspaceName.dev.azuresynapse.net/$subresource/$($sqlScript.name)?api-version=2020-02-01"
    
          #Assign Synapse Workspace Administrator Role to UAMI
          $body = $fileContent
          Invoke-RestMethod -Method Put -ContentType "application/json" -Uri $uri -Headers $headers -Body $body
        }
      }

      #Create Linked Service artifacts.
      Write-Host "Deploying Linked Service:"
      Write-Host "-----------------------------------------------------------------------"
      foreach ($linkedService in $sampleArtifactCollection.artifacts.linkedServices) {
        $fileContent = Invoke-WebRequest $linkedService.definitionFilePath

        if ($linkedService.tokens.length -gt 0) {
          foreach ($token in $linkedService.tokens) {
            $fileContent = $fileContent -replace $token, $synapseTokens.Get_Item($token)
          }
        }

        $definitionFilePath = [guid]::NewGuid()
        Set-Content -Path $definitionFilePath $fileContent 
        Set-AzSynapseLinkedService -WorkspaceName $SynapseWorkspaceName -Name $linkedService.name -DefinitionFile $definitionFilePath 
        Remove-Item -Path $definitionFilePath
      }

      #Create Database artifacts.
      
      Write-Host "Deploying Database Scripts:"
      Write-Host "-----------------------------------------------------------------------"
      foreach ($database in $sampleArtifactCollection.artifacts.databases) {
        $fileContent = Invoke-WebRequest $database.definitionFilePath
        Write-Host $RawDataLakeAccountName
        $fileContent = $fileContent -replace "<adworksls>", $RawDataLakeAccountName
        Write-Host $fileContent
	
        if ($database.interface.ToLower() -eq "powershell") {
          # ## Action to perform if the condition is true 
        }
        elseif ($database.interface.ToLower() -eq "rest") {
          Write-Host "Creating database: $($database.name) via REST API"
          $subresource = "databases"
          $uri = "https://$SynapseWorkspaceName.dev.azuresynapse.net/$subresource/$($database.name)?api-version=2020-02-01"
    
          #Assign Synapse Workspace Administrator Role to UAMI
          $body = $fileContent
          Invoke-RestMethod -Method Put -ContentType "application/json" -Uri $uri -Headers $headers -Body $body
          if ($database.name -eq "adworks") {
            foreach ($table in $sampleArtifactCollection.artifacts.databases.tables) {
              $fileContent = Invoke-WebRequest $table.definitionFilePath
              $fileContent = $fileContent -replace "<adworksls>", $RawDataLakeAccountName
              Write-Host $fileContent

              if ($table.interface.ToLower() -eq "powershell") {
                # ## Action to perform if the condition is true 
              }
              elseif ($table.interface.ToLower() -eq "rest") {
                Write-Host "Creating table: $($table.name) via REST API"
                $subresource = "databases"
                $uri1 = "https://$SynapseWorkspaceName.dev.azuresynapse.net/$subresource/$($table.name)?api-version=2020-02-01"
    
                #Assign Synapse Workspace Administrator Role to UAMI
                $body = $fileContent
                Invoke-RestMethod -Method Put -ContentType "application/json" -Uri $uri1 -Headers $headers -Body $body
              }
		 
            }
          }
          if ($database.name -eq "adworks") {
            foreach ($relationship in $sampleArtifactCollection.artifacts.databases.relationships) {
              $fileContent = Invoke-WebRequest $relationship.definitionFilePath

              Write-Host $fileContent

              if ($relationship.interface.ToLower() -eq "powershell") {
                # ## Action to perform if the condition is true 
              }
              elseif ($relationship.interface.ToLower() -eq "rest") {
                Write-Host "Creating relationship: $($relationship.name) via REST API"
                $subresource = "databases"
                $uri1 = "https://$SynapseWorkspaceName.dev.azuresynapse.net/$subresource/$($relationship.name)?api-version=2020-02-01"
    
                #Assign Synapse Workspace Administrator Role to UAMI
                $body = $fileContent
                Invoke-RestMethod -Method Put -ContentType "application/json" -Uri $uri1 -Headers $headers -Body $body
              }
		 
            }
          }
        }
      }

      #Create Dataset artifacts.
      Write-Host "Deploying Datasets:"
      Write-Host "-----------------------------------------------------------------------"
      foreach ($dataset in $sampleArtifactCollection.artifacts.datasets) {
        $fileContent = Invoke-WebRequest $dataset.definitionFilePath

        if ($dataset.tokens.length -gt 0) {
          foreach ($token in $dataset.tokens) {
            $fileContent = $fileContent -replace $token, $synapseTokens.Get_Item($token)
          }
        }
        Write-Host $fileContent
        Write-Host $SynapseWorkspaceName
        Write-Host $dataset.name
        Write-Host $definitionFilePath
        $definitionFilePath = [guid]::NewGuid()
        Set-Content -Path $definitionFilePath $fileContent
        Set-AzSynapseDataset -WorkspaceName $SynapseWorkspaceName -Name $dataset.name -DefinitionFile $definitionFilePath
        Remove-Item -Path $definitionFilePath
      }

      #Create Dataflows artifacts.
      Write-Host "Deploying Dataflows:"
      Write-Host "-----------------------------------------------------------------------"
      foreach ($dataflow in $sampleArtifactCollection.artifacts.dataflows) {
        $fileContent = Invoke-WebRequest $dataflow.definitionFilePath
        Write-Host $definitionFilePath
        if ($dataflow.tokens.length -gt 0) {
          foreach ($token in $dataflow.tokens) {
            $fileContent = $fileContent -replace $token, $synapseTokens.Get_Item($token)
          }
        }
        Write-Host $fileContent
        Write-Host $SynapseWorkspaceName
        Write-Host $dataflow.name
        Write-Host $definitionFilePath
        $definitionFilePath = [guid]::NewGuid()
        Set-Content -Path $definitionFilePath $fileContent
        Set-AzSynapseDataFlow -WorkspaceName $SynapseWorkspaceName -Name $dataflow.name -DefinitionFile $definitionFilePath
        Remove-Item -Path $definitionFilePath
      }

      #Create Notebook artifacts.
      Write-Host "Deploying Notebooks:"
      Write-Host "-----------------------------------------------------------------------"
      foreach ($notebook in $sampleArtifactCollection.artifacts.notebooks) {
        $fileContent = Invoke-WebRequest $notebook.definitionFilePath

        if ($notebook.tokens.length -gt 0) {
          foreach ($token in $notebook.tokens) {
            $fileContent = $fileContent -replace $token, $synapseTokens.Get_Item($token)
          }
        }

        if ($notebook.interface.ToLower() -eq "powershell") {
          $definitionFilePath = [guid]::NewGuid()
          Set-Content -Path $definitionFilePath $fileContent
          Set-AzSynapseNotebook -WorkspaceName $SynapseWorkspaceName -Name $notebook.name -DefinitionFile $definitionFilePath -FolderPath $notebook.workspaceFolderPath -SparkPoolName SparkPool -ExecutorCount 2
          if ($notebook.name.ToLower() -eq "creating_adworks_database") {
            #Invoke-AzMLWorkspaceNotebook -ResourceGroupName $Resourcegroupname -WorkspaceName $SynapseWorkspaceName
          }
          Remove-Item -Path $definitionFilePath
        }
        elseif ($notebook.interface.ToLower() -eq "rest") {
          ## Action to perform if the condition is true #>
        }
      }
      
      #Create Pipeline artifacts.
      Write-Host "Deploying Pipelines:"
      Write-Host "-----------------------------------------------------------------------"
      foreach ($pipeline in $sampleArtifactCollection.artifacts.pipelines) {
        $fileContent = Invoke-WebRequest $pipeline.definitionFilePath

        if ($pipeline.tokens.length -gt 0) {
            
          foreach ($token in $pipeline.tokens) {
            $fileContent = $fileContent -replace $token, $synapseTokens.Get_Item($token)
          }
        }

        $definitionFilePath = [guid]::NewGuid()
        Write-Host $definitionFilePath
        #Write-Host $fileContent
        Set-Content -Path $definitionFilePath $fileContent
        Write-Host $SynapseWorkspaceName
        Write-Host $pipeline.name
        Write-Host $definitionFilePath
        Set-AzSynapsePipeline -WorkspaceName $SynapseWorkspaceName -Name $pipeline.name -DefinitionFile $definitionFilePath
        #Invoke-AzSynapsePipeline -WorkspaceName $SynapseWorkspaceName -PipelineName $pipeline.name
        Remove-Item -Path $definitionFilePath
      }

      break
    }
  }
  
  Write-Host "copying CSV files:"  
  #Copy File to container.
  if ((Get-Module -ListAvailable Az.Accounts) -eq $null) {
    Install-Module -Name Az.Accounts -Force
  }

  $uri = "https://raw.githubusercontent.com/CSALabsAutomation/azure-synapse-labs/main/environments/env1/Sample/Artifacts/TaxiDataFiles/Geography.csv";
  $bacpacFileName = "Geography.csv";
  #$storageaccount = Get-AzStorageAccount -ResourceGroupName $Resourcegroupname;
  $storageaccountkey = Get-AzStorageAccountKey -ResourceGroupName $Resourcegroupname -Name $RawDataLakeAccountName;

  $ctx = New-AzStorageContext -StorageAccountName $RawDataLakeAccountName -StorageAccountKey $storageaccountkey.Value[0]

  Invoke-WebRequest -Uri $uri -OutFile $bacpacFileName 
  Set-AzStorageBlobContent -File $bacpacFileName -Container "raw" -Blob 'Geography.csv' -Context $ctx

  $uri1 = "https://raw.githubusercontent.com/CSALabsAutomation/azure-synapse-labs/main/environments/env1/Sample/Artifacts/TaxiDataFiles/date.csv";
  $bacpacFileName1 = "date.csv";
  #$storageaccount1 = Get-AzStorageAccount -ResourceGroupName $Resourcegroupname;
  $storageaccountkey1 = Get-AzStorageAccountKey -ResourceGroupName $Resourcegroupname -Name $RawDataLakeAccountName;

  $ctx1 = New-AzStorageContext -StorageAccountName $RawDataLakeAccountName -StorageAccountKey $storageaccountkey1.Value[0]

  Invoke-WebRequest -Uri $uri1 -OutFile $bacpacFileName1 
  Set-AzStorageBlobContent -File $bacpacFileName1 -Container "raw" -Blob 'date.csv' -Context $ctx1

  $uri2 = "https://raw.githubusercontent.com/CSALabsAutomation/azure-synapse-labs/main/environments/env1/Sample/Artifacts/TaxiDataFiles/HackneyLicense.csv";
  $bacpacFileName2 = "HackneyLicense.csv";
  #$storageaccount2 = Get-AzStorageAccount -ResourceGroupName $Resourcegroupname;
  $storageaccountkey2 = Get-AzStorageAccountKey -ResourceGroupName $Resourcegroupname -Name $RawDataLakeAccountName;

  $ctx2 = New-AzStorageContext -StorageAccountName $RawDataLakeAccountName -StorageAccountKey $storageaccountkey2.Value[0]

  Invoke-WebRequest -Uri $uri2 -OutFile $bacpacFileName2 
  Set-AzStorageBlobContent -File $bacpacFileName2 -Container "raw" -Blob 'HackneyLicense.csv' -Context $ctx2

  $uri3 = "https://raw.githubusercontent.com/CSALabsAutomation/azure-synapse-labs/main/environments/env1/Sample/Artifacts/TaxiDataFiles/Medallion.csv";
  $bacpacFileName3 = "Medallion.csv";
  #$storageaccount3 = Get-AzStorageAccount -ResourceGroupName $Resourcegroupname;
  $storageaccountkey3 = Get-AzStorageAccountKey -ResourceGroupName $Resourcegroupname -Name $RawDataLakeAccountName;

  $ctx3 = New-AzStorageContext -StorageAccountName $RawDataLakeAccountName -StorageAccountKey $storageaccountkey3.Value[0]

  Invoke-WebRequest -Uri $uri3 -OutFile $bacpacFileName3 
  Set-AzStorageBlobContent -File $bacpacFileName3 -Container "raw" -Blob 'Medallion.csv' -Context $ctx3

  $uri4 = "https://raw.githubusercontent.com/CSALabsAutomation/azure-synapse-labs/main/environments/env1/Sample/Artifacts/TaxiDataFiles/Time.csv";
  $bacpacFileName4 = "Time.csv";
  #$storageaccount4 = Get-AzStorageAccount -ResourceGroupName $Resourcegroupname;
  $storageaccountkey4 = Get-AzStorageAccountKey -ResourceGroupName $Resourcegroupname -Name $RawDataLakeAccountName;

  $ctx4 = New-AzStorageContext -StorageAccountName $RawDataLakeAccountName -StorageAccountKey $storageaccountkey4.Value[0]

  Invoke-WebRequest -Uri $uri4 -OutFile $bacpacFileName4 
  Set-AzStorageBlobContent -File $bacpacFileName4 -Container "raw" -Blob 'Time.csv' -Context $ctx4

  $uri5 = "https://raw.githubusercontent.com/CSALabsAutomation/azure-synapse-labs/main/environments/env1/Sample/Artifacts/TaxiDataFiles/Trip.csv";
  $bacpacFileName5 = "Trip.csv";
  #$storageaccount5 = Get-AzStorageAccount -ResourceGroupName $Resourcegroupname;
  $storageaccountkey5 = Get-AzStorageAccountKey -ResourceGroupName $Resourcegroupname -Name $RawDataLakeAccountName;

  $ctx5 = New-AzStorageContext -StorageAccountName $RawDataLakeAccountName -StorageAccountKey $storageaccountkey5.Value[0]

  Invoke-WebRequest -Uri $uri5 -OutFile $bacpacFileName5 
  Set-AzStorageBlobContent -File $bacpacFileName5 -Container "raw" -Blob 'Trip.csv' -Context $ctx5

  $uri6 = "https://raw.githubusercontent.com/CSALabsAutomation/azure-synapse-labs/main/environments/env1/Sample/Artifacts/TaxiDataFiles/Weather.csv";
  $bacpacFileName6 = "Weather.csv";
  #$storageaccount6 = Get-AzStorageAccount -ResourceGroupName $Resourcegroupname;
  $storageaccountkey6 = Get-AzStorageAccountKey -ResourceGroupName $Resourcegroupname -Name $RawDataLakeAccountName;

  $ctx6 = New-AzStorageContext -StorageAccountName $RawDataLakeAccountName -StorageAccountKey $storageaccountkey6.Value[0]

  Invoke-WebRequest -Uri $uri6 -OutFile $bacpacFileName6 
  Set-AzStorageBlobContent -File $bacpacFileName6 -Container "raw" -Blob 'Weather.csv' -Context $ctx6

  $uri7 = "https://raw.githubusercontent.com/CSALabsAutomation/azure-synapse-labs/main/environments/env1/Sample/Artifacts/TaxiDataFiles/yellow500.parquet";
  $bacpacFileName7 = "yellow500.parquet";
  #$storageaccount7 = Get-AzStorageAccount -ResourceGroupName $Resourcegroupname;
  $storageaccountkey7 = Get-AzStorageAccountKey -ResourceGroupName $Resourcegroupname -Name $RawDataLakeAccountName;

  $ctx7 = New-AzStorageContext -StorageAccountName $RawDataLakeAccountName -StorageAccountKey $storageaccountkey7.Value[0]

  Invoke-WebRequest -Uri $uri7 -OutFile $bacpacFileName7 
  Set-AzStorageBlobContent -File $bacpacFileName7 -Container "raw" -Blob 'yellow/puYear=2022/puMonth=01/yellow.parquet' -Context $ctx7

  Write-Host "-----------------------------------------------------------Synapse retail files---------------------------------------------------------------"

  $uri8 = "https://raw.githubusercontent.com/CSALabsAutomation/azure-synapse-labs/main/environments/env1/Sample/Artifacts/SynapseRetailFiles/Calendar.csv";
  $bacpacFileName8 = "Calendar.csv";
  #$storageaccount8 = Get-AzStorageAccount -ResourceGroupName $Resourcegroupname;
  $storageaccountkey8 = Get-AzStorageAccountKey -ResourceGroupName $Resourcegroupname -Name $RawDataLakeAccountName;

  $ctx8 = New-AzStorageContext -StorageAccountName $RawDataLakeAccountName -StorageAccountKey $storageaccountkey8.Value[0]

  Invoke-WebRequest -Uri $uri8 -OutFile $bacpacFileName8 
  Set-AzStorageBlobContent -File $bacpacFileName8 -Container "raw" -Blob 'SynapseRetailFiles/Calendar.csv' -Context $ctx8

  $uri9 = "https://raw.githubusercontent.com/CSALabsAutomation/azure-synapse-labs/main/environments/env1/Sample/Artifacts/SynapseRetailFiles/ChannelType.csv";
  $bacpacFileName9 = "ChannelType.csv";
  #$storageaccount9 = Get-AzStorageAccount -ResourceGroupName $Resourcegroupname;
  $storageaccountkey9 = Get-AzStorageAccountKey -ResourceGroupName $Resourcegroupname -Name $RawDataLakeAccountName;

  $ctx9 = New-AzStorageContext -StorageAccountName $RawDataLakeAccountName -StorageAccountKey $storageaccountkey9.Value[0]

  Invoke-WebRequest -Uri $uri9 -OutFile $bacpacFileName9 
  Set-AzStorageBlobContent -File $bacpacFileName9 -Container "raw" -Blob 'SynapseRetailFiles/ChannelType.csv' -Context $ctx9

  $uri10 = "https://raw.githubusercontent.com/CSALabsAutomation/azure-synapse-labs/main/environments/env1/Sample/Artifacts/SynapseRetailFiles/Country.csv";
  $bacpacFileName10 = "Country.csv";
  #$storageaccount10 = Get-AzStorageAccount -ResourceGroupName $Resourcegroupname;
  $storageaccountkey10 = Get-AzStorageAccountKey -ResourceGroupName $Resourcegroupname -Name $RawDataLakeAccountName;

  $ctx10 = New-AzStorageContext -StorageAccountName $RawDataLakeAccountName -StorageAccountKey $storageaccountkey10.Value[0]

  Invoke-WebRequest -Uri $uri10 -OutFile $bacpacFileName10 
  Set-AzStorageBlobContent -File $bacpacFileName10 -Container "raw" -Blob 'SynapseRetailFiles/Country.csv' -Context $ctx10

  $uri11 = "https://raw.githubusercontent.com/CSALabsAutomation/azure-synapse-labs/main/environments/env1/Sample/Artifacts/SynapseRetailFiles/CustomerData.csv";
  $bacpacFileName11 = "CustomerData.csv";
  #$storageaccount11 = Get-AzStorageAccount -ResourceGroupName $Resourcegroupname;
  $storageaccountkey11 = Get-AzStorageAccountKey -ResourceGroupName $Resourcegroupname -Name $RawDataLakeAccountName;

  $ctx11 = New-AzStorageContext -StorageAccountName $RawDataLakeAccountName -StorageAccountKey $storageaccountkey11.Value[0]

  Invoke-WebRequest -Uri $uri11 -OutFile $bacpacFileName11
  Set-AzStorageBlobContent -File $bacpacFileName11 -Container "raw" -Blob 'SynapseRetailFiles/CustomerData.csv' -Context $ctx11

  $uri12 = "https://raw.githubusercontent.com/CSALabsAutomation/azure-synapse-labs/main/environments/env1/Sample/Artifacts/SynapseRetailFiles/Location.csv";
  $bacpacFileName12 = "Location.csv";
  #$storageaccount12 = Get-AzStorageAccount -ResourceGroupName $Resourcegroupname;
  $storageaccountkey12 = Get-AzStorageAccountKey -ResourceGroupName $Resourcegroupname -Name $RawDataLakeAccountName;

  $ctx12 = New-AzStorageContext -StorageAccountName $RawDataLakeAccountName -StorageAccountKey $storageaccountkey12.Value[0]

  Invoke-WebRequest -Uri $uri12 -OutFile $bacpacFileName12
  Set-AzStorageBlobContent -File $bacpacFileName12 -Container "raw" -Blob 'SynapseRetailFiles/Location.csv' -Context $ctx12

  $uri13 = "https://raw.githubusercontent.com/CSALabsAutomation/azure-synapse-labs/main/environments/env1/Sample/Artifacts/SynapseRetailFiles/ProductData.csv";
  $bacpacFileName13 = "ProductData.csv";
  #$storageaccount13 = Get-AzStorageAccount -ResourceGroupName $Resourcegroupname;
  $storageaccountkey13 = Get-AzStorageAccountKey -ResourceGroupName $Resourcegroupname -Name $RawDataLakeAccountName;

  $ctx13 = New-AzStorageContext -StorageAccountName $RawDataLakeAccountName -StorageAccountKey $storageaccountkey13.Value[0]

  Invoke-WebRequest -Uri $uri13 -OutFile $bacpacFileName13 
  Set-AzStorageBlobContent -File $bacpacFileName13 -Container "raw" -Blob 'SynapseRetailFiles/ProductData.csv' -Context $ctx13

  $uri14 = "https://raw.githubusercontent.com/CSALabsAutomation/azure-synapse-labs/main/environments/env1/Sample/Artifacts/SynapseRetailFiles/Reseller.csv";
  $bacpacFileName14 = "Reseller.csv";
  #$storageaccount14 = Get-AzStorageAccount -ResourceGroupName $Resourcegroupname;
  $storageaccountkey14 = Get-AzStorageAccountKey -ResourceGroupName $Resourcegroupname -Name $RawDataLakeAccountName;

  $ctx14 = New-AzStorageContext -StorageAccountName $RawDataLakeAccountName -StorageAccountKey $storageaccountkey14.Value[0]

  Invoke-WebRequest -Uri $uri14 -OutFile $bacpacFileName14 
  Set-AzStorageBlobContent -File $bacpacFileName14 -Container "raw" -Blob 'SynapseRetailFiles/Reseller.csv' -Context $ctx14

  $uri15 = "https://raw.githubusercontent.com/CSALabsAutomation/azure-synapse-labs/main/environments/env1/Sample/Artifacts/SynapseRetailFiles/Sales.csv";
  $bacpacFileName15 = "Sales.parquet";
  #$storageaccount15 = Get-AzStorageAccount -ResourceGroupName $Resourcegroupname;
  $storageaccountkey15 = Get-AzStorageAccountKey -ResourceGroupName $Resourcegroupname -Name $RawDataLakeAccountName;

  $ctx15 = New-AzStorageContext -StorageAccountName $RawDataLakeAccountName -StorageAccountKey $storageaccountkey15.Value[0]

  Invoke-WebRequest -Uri $uri15 -OutFile $bacpacFileName15
  Set-AzStorageBlobContent -File $bacpacFileName15 -Container "raw" -Blob 'SynapseRetailFiles/Sales.csv' -Context $ctx15

  $uri16 = "https://raw.githubusercontent.com/CSALabsAutomation/azure-synapse-labs/main/environments/env1/Sample/Artifacts/SynapseRetailFiles/SalesOrder.csv";
  $bacpacFileName16 = "SalesOrder.csv";
  #$storageaccount16 = Get-AzStorageAccount -ResourceGroupName $Resourcegroupname;
  $storageaccountkey16 = Get-AzStorageAccountKey -ResourceGroupName $Resourcegroupname -Name $RawDataLakeAccountName;

  $ctx16 = New-AzStorageContext -StorageAccountName $RawDataLakeAccountName -StorageAccountKey $storageaccountkey16.Value[0]

  Invoke-WebRequest -Uri $uri16 -OutFile $bacpacFileName16 
  Set-AzStorageBlobContent -File $bacpacFileName16 -Container "raw" -Blob 'SynapseRetailFiles/SalesOrder.csv' -Context $ctx16


  $uri17 = "https://raw.githubusercontent.com/CSALabsAutomation/azure-synapse-labs/main/environments/env1/Sample/Artifacts/SynapseRetailFiles/SalesTerritory.csv";
  $bacpacFileName17 = "SalesTerritory.csv";
  #$storageaccount17 = Get-AzStorageAccount -ResourceGroupName $Resourcegroupname;
  $storageaccountkey17 = Get-AzStorageAccountKey -ResourceGroupName $Resourcegroupname -Name $RawDataLakeAccountName;

  $ctx17 = New-AzStorageContext -StorageAccountName $RawDataLakeAccountName -StorageAccountKey $storageaccountkey17.Value[0]

  Invoke-WebRequest -Uri $uri17 -OutFile $bacpacFileName17 
  Set-AzStorageBlobContent -File $bacpacFileName17 -Container "raw" -Blob 'SynapseRetailFiles/SalesTerritory.csv' -Context $ctx17

  $uri18 = "https://raw.githubusercontent.com/CSALabsAutomation/azure-synapse-labs/main/environments/env1/Sample/Artifacts/HolidayData/holiday.parquet";
  $bacpacFileName18 = "holiday.parquet";
  #$storageaccount18 = Get-AzStorageAccount -ResourceGroupName $Resourcegroupname;
  $storageaccountkey18 = Get-AzStorageAccountKey -ResourceGroupName $Resourcegroupname -Name $RawDataLakeAccountName;

  $ctx18 = New-AzStorageContext -StorageAccountName $RawDataLakeAccountName -StorageAccountKey $storageaccountkey18.Value[0]

  Invoke-WebRequest -Uri $uri18 -OutFile $bacpacFileName18 
  Set-AzStorageBlobContent -File $bacpacFileName18 -Container "raw" -Blob 'holiday.parquet' -Context $ctx18

  Write-Host "copying CSV files Completed." 
}

#------------------------------------------------------------------------------------------------------------
# MAIN SCRIPT BODY
#------------------------------------------------------------------------------------------------------------

$retries = 10
$secondsDelay = 60

#------------------------------------------------------------------------------------------------------------
# CONTROL PLANE OPERATION: ASSIGN SYNAPSE WORKSPACE ADMINISTRATOR TO USER-ASSIGNED MANAGED IDENTITY
# UAMI needs Synapse Admin rights before it can make calls to the Data Plane APIs to create Synapse objects
#------------------------------------------------------------------------------------------------------------

$token = (Get-AzAccessToken -Resource "https://dev.azuresynapse.net").Token
$headers = @{ Authorization = "Bearer $token" }

$uri = "https://$SynapseWorkspaceName.dev.azuresynapse.net/rbac/roleAssignments?api-version=2020-02-01-preview"

#Assign Synapse Workspace Administrator Role to UAMI
$body = "{
  roleId: ""6e4bf58a-b8e1-4cc3-bbf9-d73143322b78"",
  principalId: ""$UAMIIdentityID""
}"

Write-Host "Assign Synapse Administrator Role to UAMI..."

Invoke-RestMethod -Method Post -ContentType "application/json" -Uri $uri -Headers $headers -Body $body

#------------------------------------------------------------------------------------------------------------
# CONTROL PLANE OPERATION: ASSIGN SYNAPSE APACHE SPARK ADMINISTRATOR TO AZURE ML LINKED SERVICE MSI
# If AI Services are deployed, then Azure ML MSI needs Synapse Spark Admin rights to use Spark clusters as compute
#------------------------------------------------------------------------------------------------------------

if (-not ([string]::IsNullOrEmpty($AzMLSynapseLinkedServiceIdentityID))) {
  #Assign Synapse Apache Spark Administrator Role to Azure ML Linked Service Managed Identity
  # https://docs.microsoft.com/en-us/azure/machine-learning/how-to-link-synapse-ml-workspaces#link-workspaces-with-the-python-sdk

  $body = "{
    roleId: ""c3a6d2f1-a26f-4810-9b0f-591308d5cbf1"",
    principalId: ""$AzMLSynapseLinkedServiceIdentityID""
  }"

  Write-Host "Assign Synapse Apache Spark Administrator Role to Azure ML Linked Service Managed Identity..."
  Invoke-RestMethod -Method Post -ContentType "application/json" -Uri $uri -Headers $headers -Body $body

  # From: https://docs.microsoft.com/en-us/azure/synapse-analytics/security/how-to-manage-synapse-rbac-role-assignments
  # Changes made to Synapse RBAC role assignments may take 2-5 minutes to take effect.
  # Retry logic required before calling further APIs
}

#------------------------------------------------------------------------------------------------------------
# DATA PLANE OPERATION: CREATE AZURE KEY VAULT LINKED SERVICE
#------------------------------------------------------------------------------------------------------------

#Create AKV Linked Service. Linked Service name same as Key Vault's.

$body = "{
  name: ""$KeyVaultName"",
  properties: {
      annotations: [],
      type: ""AzureKeyVault"",
      typeProperties: {
          baseUrl: ""https://$KeyVaultName.vault.azure.net/""
      }
  }
}"

Save-SynapseLinkedService $SynapseWorkspaceName $KeyVaultName $body

#------------------------------------------------------------------------------------------------------------
# DATA PLANE OPERATION: CREATE WORKSPACE, RAW AND CURATED DATA LAKES LINKED SERVICES
#------------------------------------------------------------------------------------------------------------

$dataLakeAccountNames = $WorkspaceDataLakeAccountName, $RawDataLakeAccountName, $CuratedDataLakeAccountName
$dataLakeDFSEndpoints = "https://$WorkspaceDataLakeAccountName.dfs.core.windows.net", "https://$RawDataLakeAccountName.dfs.core.windows.net", "https://$CuratedDataLakeAccountName.dfs.core.windows.net"

for ($i = 0; $i -lt $dataLakeAccountNames.Length ; $i++ ) {

  $body = "{
    name: ""$($dataLakeAccountNames[$i])"",
    properties: {
      annotations: [],
      type: ""AzureBlobFS"",
      typeProperties: {
        url: ""$($dataLakeDFSEndpoints[$i])""
      },
      connectVia: {
        referenceName: ""AutoResolveIntegrationRuntime"",
        type: ""IntegrationRuntimeReference""
      }
    }
  }"

  Save-SynapseLinkedService $SynapseWorkspaceName $dataLakeAccountNames[$i] $body
}

#------------------------------------------------------------------------------------------------------------
# DATA PLANE OPERATION: CREATE AZURE ML LINKED SERVICE
#------------------------------------------------------------------------------------------------------------
#-AzMLWorkspaceName paramater will be passed blank if AI workload is not deployed.

if ($CtrlDeployAI) {
  $body = "{
    name: ""$AzMLWorkspaceName"",
    properties: {
      annotations: [],
      type: ""AzureMLService"",
      typeProperties: {
          subscriptionId: ""$SubscriptionID"",
          resourceGroupName: ""$ResourceGroupName"",
          mlWorkspaceName: ""$AzMLWorkspaceName"",
          authentication: ""MSI""
      },
      connectVia: {
          referenceName: ""AutoResolveIntegrationRuntime"",
          type: ""IntegrationRuntimeReference""
      }
    }
  }"

  Save-SynapseLinkedService $SynapseWorkspaceName $AzMLWorkspaceName $body
}

#------------------------------------------------------------------------------------------------------------
# DATA PLANE OPERATION: CREATE COSMOSDB LINKED SERVICE
#------------------------------------------------------------------------------------------------------------
#-CosmosDBAccountName paramater will be passed blank if CosmosDB workload is not deployed.

if ($CtrlDeployCosmosDB) {
  $body = "{
  name: ""$CosmosDBAccountName"",
  properties: {
    annotations: [],
    type: ""CosmosDb"",
    typeProperties: {
      connectionString: ""AccountEndpoint=https://$CosmosDBAccountName.documents.azure.com:443/;Database=OperationalDB"",
      accountKey: {
        type: ""AzureKeyVaultSecret"",
        store: {
          referenceName: ""$KeyVaultName"",
          type: ""LinkedServiceReference""
        },
        secretName: ""$CosmosDBAccountName-Key""
      }
    },
    connectVia: {
      referenceName: ""AutoResolveIntegrationRuntime"",
      type: ""IntegrationRuntimeReference""
    }
  }
}"

  Save-SynapseLinkedService $SynapseWorkspaceName $CosmosDBAccountName $body
}

#------------------------------------------------------------------------------------------------------------
# DATA PLANE OPERATION: CREATE COGNITIVE SERVICES (TEXT ANALYTICS AND ANOMALY DETECTOR) LINKED SERVICES
#------------------------------------------------------------------------------------------------------------
if ($CtrlDeployAI) {
  $cognitiveServiceNames = $TextAnalyticsAccountName, $AnomalyDetectorAccountName
  $cognitiveServiceEndpoints = $TextAnalyticsEndpoint, $AnomalyDetectorEndpoint
  $cognitiveServiceTypes = "TextAnalytics", "AnomalyDetector"

  for ($i = 0; $i -lt $cognitiveServiceNames.Length ; $i++ ) {
    $body = "{
      name: ""$($cognitiveServiceNames[$i])"",
      properties: {
          annotations: [],
          type: ""CognitiveService"",
          typeProperties: {
              subscriptionId: ""$SubscriptionID"",
              resourceGroup: ""$ResourceGroupName"",
              csName: ""$($cognitiveServiceNames[$i])"",
              csKind: ""$($cognitiveServiceTypes[$i])"",
              csLocation: ""$ResourceGroupLocation"",
              endPoint: ""$($cognitiveServiceEndpoints[$i])"",
              csKey: {
                  type: ""AzureKeyVaultSecret"",
                  store: {
                      referenceName: ""$KeyVaultName"",
                      type: ""LinkedServiceReference""
                  },
                  secretName: ""$($cognitiveServiceNames[$i])-Key""
              }
          },
          connectVia: {
              referenceName: ""AutoResolveIntegrationRuntime"",
              type: ""IntegrationRuntimeReference""
          }
      }
    }"
  
    Save-SynapseLinkedService $SynapseWorkspaceName $cognitiveServiceNames[$i] $body
  }
}

#------------------------------------------------------------------------------------------------------------
# DATA PLANE OPERATOR: CREATE AND APPROVE MANAGED PRIVATE ENDPOINTS
# For vNet-integrated deployments, create the private endpoints to the resources required by Synapse managed vNet
#------------------------------------------------------------------------------------------------------------

#Create Managed Private Endpoints
if ($NetworkIsolationMode -eq "vNet") {
  [string[]] $managedPrivateEndpointNames = $KeyVaultName, $WorkspaceDataLakeAccountName, $RawDataLakeAccountName, $CuratedDataLakeAccountName
  [string[]] $managedPrivateEndpointIDs = $KeyVaultID, $WorkspaceDataLakeAccountID, $RawDataLakeAccountID, $CuratedDataLakeAccountID
  [string[]] $managedPrivateEndpointGroups = 'vault', 'dfs', 'dfs', 'dfs'

  #If AI workload is deployed then add cognitive services to the list of managed endpoints.
  if ($CtrlDeployAI) {
    [string[]] $cognitiveServicePrivateEndpointNames = $TextAnalyticsAccountName, $AnomalyDetectorAccountName
    [string[]] $cognitiveServicePrivateEndpointIDs = $TextAnalyticsAccountID, $AnomalyDetectorAccountID
    [string[]] $cognitiveServicePrivateEndpointGroups = 'account', 'account'

    $managedPrivateEndpointNames += $cognitiveServicePrivateEndpointNames
    $managedPrivateEndpointIDs += $cognitiveServicePrivateEndpointIDs
    $managedPrivateEndpointGroups += $cognitiveServicePrivateEndpointGroups
  }

  #If CosmosDB operational workload is deployed then add CosmosDB SQL and Analytical subsystems to the list of managed endpoints.
  if ($CtrlDeployCosmosDB) {
    [string[]] $cosmosDBPrivateEndpointNames = $CosmosDBAccountName, $CosmosDBAccountName
    [string[]] $cosmosDBPrivateEndpointIDs = $CosmosDBAccountID, $CosmosDBAccountID
    [string[]] $cosmosDBPrivateEndpointGroups = 'Analytical', 'Sql'
    
    $managedPrivateEndpointNames += $cosmosDBPrivateEndpointNames
    $managedPrivateEndpointIDs += $cosmosDBPrivateEndpointIDs
    $managedPrivateEndpointGroups += $cosmosDBPrivateEndpointGroups
  }

  for ($i = 0; $i -le ($managedPrivateEndpointNames.Length - 1); $i += 1) {
    $managedPrivateEndpointName = [System.String]::Concat($managedPrivateEndpointNames[$i], "-", $managedPrivateEndpointGroups[$i])
    $managedPrivateEndpointID = $managedPrivateEndpointIDs[$i]
    $managedPrivateEndpointGroup = $managedPrivateEndpointGroups[$i] 

    $uri = "https://$SynapseWorkspaceName.dev.azuresynapse.net"
    $uri += "/managedVirtualNetworks/default/managedPrivateEndpoints/$managedPrivateEndpointName"
    $uri += "?api-version=2019-06-01-preview"

    $body = "{
        name: ""$managedPrivateEndpointName-$managedPrivateEndpointGroup"",
        type: ""Microsoft.Synapse/workspaces/managedVirtualNetworks/managedPrivateEndpoints"",
        properties: {
          privateLinkResourceId: ""$managedPrivateEndpointID"",
          groupId: ""$managedPrivateEndpointGroup"",
          name: ""$managedPrivateEndpointName""
        }
    }"

    Write-Host "Create Managed Private Endpoint for $managedPrivateEndpointName..."
    $retrycount = 1
    $completed = $false
    
    while (-not $completed) {
      try {
        Invoke-RestMethod -Method Put -ContentType "application/json" -Uri $uri -Headers $headers -Body $body -ErrorAction Stop
        Write-Host "Managed private endpoint for $managedPrivateEndpointName created successfully."
        $completed = $true
      }
      catch {
        if ($retrycount -ge $retries) {
          Write-Host "Managed private endpoint for $managedPrivateEndpointName creation failed the maximum number of $retryCount times."
          throw
        }
        else {
          Write-Host "Managed private endpoint creation for $managedPrivateEndpointName failed $retryCount time(s). Retrying in $secondsDelay seconds."
          Start-Sleep $secondsDelay
          $retrycount++
        }
      }
    }
  }

  #30 second delay interval for private link provisioning state = Succeeded
  $secondsDelay = 30

  #Approve Private Endpoints
  for ($i = 0; $i -le ($managedPrivateEndpointNames.Length - 1); $i += 1) {
    $retrycount = 1
    $completed = $false
    
    while (-not $completed) {
      try {
        $managedPrivateEndpointName = [System.String]::Concat($managedPrivateEndpointNames[$i], "-", $managedPrivateEndpointGroups[$i])
        $managedPrivateEndpointID = $managedPrivateEndpointIDs[$i]
        # Approve KeyVault Private Endpoint
        $privateEndpoints = Get-AzPrivateEndpointConnection -PrivateLinkResourceId $managedPrivateEndpointID -ErrorAction Stop | where-object { $_.PrivateEndpoint.Id -match ($SynapseWorkspaceName + "." + $managedPrivateEndpointName) } | select-object Id, ProvisioningState, PrivateLinkServiceConnectionState
        
        foreach ($privateEndpoint in $privateEndpoints) {
          if ($privateEndpoint.ProvisioningState -eq "Succeeded") {
            if ($privateEndpoint.PrivateLinkServiceConnectionState.Status -eq "Pending") {
              Write-Host "Approving private endpoint for $managedPrivateEndpointName."
              Approve-AzPrivateEndpointConnection -ResourceId $privateEndpoint.Id -Description "Auto-Approved" -ErrorAction Stop    
              $completed = $true
            }
            elseif ($privateEndpoint.PrivateLinkServiceConnectionState.Status -eq "Approved") {
              $completed = $true
            }
          }
        }
        
        if (-not $completed) {
          throw "Private endpoint connection not yet provisioned."
        }
      }
      catch {
        if ($retrycount -ge $retries) {
          Write-Host "Private endpoint approval for $managedPrivateEndpointName has failed the maximum number of $retryCount times."
          throw
        }
        else {
          Write-Host "Private endpoint approval for $managedPrivateEndpointName has failed $retryCount time(s). Retrying in $secondsDelay seconds."
          Write-Warning $PSItem.ToString()
          Start-Sleep $secondsDelay
          $retrycount++
        }
      }
    }
  }
}

#------------------------------------------------------------------------------------------------------------
# DATA PLANE OPERATION: DEPLOY SAMPLE ARTIFACTS
# Deploy sample artifcats (SQL Scripts, Datasets, Linked Services, Pipelines and Notebooks) based on chosen template.
#------------------------------------------------------------------------------------------------------------

if ($CtrlDeploySampleArtifacts) {
  Save-SynapseSampleArtifacts $SynapseWorkspaceName $SampleArtifactCollectioName
}

#------------------------------------------------------------------------------------------------------------
# CONTROL PLANE OPERATOR: DISABLE PUBLIC NETWORK ACCESS
# For vNet-integrated deployments, disable public network access. Access to Synapse only through private endpoints.
#------------------------------------------------------------------------------------------------------------

if ($NetworkIsolationMode -eq "vNet") {
  $body = "{properties:{publicNetworkAccess:""Disabled""}}"
  Set-SynapseControlPlaneOperation -SynapseWorkspaceID $SynapseWorkspaceID -HttpRequestBody $body
}
