# HIPAA Compliance & AI Integration Recommendations

## Executive Summary

Your current serverless infrastructure needs **significant enhancements** for HIPAA compliance in the US healthcare industry. This document outlines critical security gaps, required AWS services, HIPAA-eligible AI components, and a phased implementation roadmap.

---

## 🚨 CRITICAL HIPAA COMPLIANCE GAPS

### Current Infrastructure Analysis

| Component | Current State | HIPAA Requirement | Status |
|-----------|--------------|-------------------|--------|
| **Data Encryption** | CloudFront HTTPS, S3 encrypted | ✅ Encryption in transit/rest | ✅ PARTIAL |
| **Access Logging** | CloudWatch Logs only | ✅ Audit trails required | ⚠️ INSUFFICIENT |
| **API Authentication** | None | ❌ Required | ❌ MISSING |
| **Data Isolation** | Single Lambda | ❌ Multi-tenancy isolation | ❌ MISSING |
| **Database** | None | ❌ Encrypted PHI storage | ❌ MISSING |
| **VPC Isolation** | Public Lambda | ❌ Private network required | ❌ MISSING |
| **WAF Protection** | None | ❌ DDoS/injection protection | ❌ MISSING |
| **Access Controls** | IAM basic | ⚠️ Least privilege + MFA | ⚠️ INSUFFICIENT |
| **Backup/DR** | None | ❌ Data recovery required | ❌ MISSING |
| **BAA with AWS** | Unknown | ❌ Required for HIPAA | ❌ REQUIRED |

### Compliance Risk Assessment: **HIGH RISK** ⚠️

**You cannot process PHI (Protected Health Information) with the current setup.**

---

## 🔒 PHASE 1: MANDATORY HIPAA TECHNICAL SAFEGUARDS (Priority: CRITICAL)

### 1.1 AWS Business Associate Agreement (BAA)
**Action:** Sign AWS BAA before processing any PHI.
- **How:** AWS Console → Support → Create Case → Request BAA
- **Cost:** Free (requires Business/Enterprise Support ~$100+/month)
- **Timeline:** 2-5 business days

### 1.2 VPC & Private Network Isolation
**Problem:** Lambda currently runs in public AWS network.

**Solution:** Deploy Lambda in VPC with private subnets.

```yaml
# serverless.yml additions
provider:
  vpc:
    securityGroupIds:
      - sg-xxxxxxxxx  # Restrictive security group
    subnetIds:
      - subnet-private-1  # Private subnet (no internet access)
      - subnet-private-2
```

**Additional Infrastructure Needed:**
```hcl
# infra/vpc.tf
resource "aws_vpc" "healthcare" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  
  tags = {
    Name = "healthcare-vpc"
    HIPAA = "true"
  }
}

resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.healthcare.id
  cidr_block        = "10.0.${count.index + 1}.0/24"
  availability_zone = data.aws_availability_zones.available.names[count.index]
  
  tags = {
    Name = "healthcare-private-${count.index + 1}"
    HIPAA = "true"
  }
}

# VPC Endpoints for AWS services (no internet egress for PHI)
resource "aws_vpc_endpoint" "s3" {
  vpc_id       = aws_vpc.healthcare.id
  service_name = "com.amazonaws.us-east-1.s3"
  route_table_ids = [aws_route_table.private.id]
}
```

**Cost Impact:** ~$0.01/hour per VPC endpoint (~$7/month)

### 1.3 Authentication & Authorization (AWS Cognito)
**Problem:** No user authentication, API is completely open.

**Solution:** Implement AWS Cognito User Pools with MFA.

```hcl
# infra/cognito.tf
resource "aws_cognito_user_pool" "healthcare" {
  name = "healthcare-users"

  # HIPAA: Password complexity requirements
  password_policy {
    minimum_length    = 12
    require_lowercase = true
    require_uppercase = true
    require_numbers   = true
    require_symbols   = true
    temporary_password_validity_days = 7
  }

  # HIPAA: MFA enforcement
  mfa_configuration = "ON"
  
  software_token_mfa_configuration {
    enabled = true
  }

  # HIPAA: Account recovery with security questions
  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }

  # HIPAA: Auto-verified attributes
  auto_verified_attributes = ["email"]

  # HIPAA: Advanced security (anomaly detection)
  user_pool_add_ons {
    advanced_security_mode = "ENFORCED"
  }

  tags = {
    HIPAA = "true"
  }
}

# API Gateway Authorizer
resource "aws_api_gateway_authorizer" "cognito" {
  name            = "cognito-authorizer"
  type            = "COGNITO_USER_POOLS"
  rest_api_id     = aws_api_gateway_rest_api.main.id
  provider_arns   = [aws_cognito_user_pool.healthcare.arn]
  identity_source = "method.request.header.Authorization"
}
```

**Cost:** ~$0.0055 per MAU (Monthly Active User), first 50k MAUs free

### 1.4 Encrypted Database for PHI Storage
**Problem:** No persistent storage, PHI cannot be stored.

**Solution:** Amazon RDS PostgreSQL with encryption at rest.

```hcl
# infra/rds.tf
resource "aws_db_instance" "healthcare" {
  identifier     = "healthcare-db"
  engine         = "postgres"
  engine_version = "15.4"
  instance_class = "db.t3.micro"  # Free tier eligible

  allocated_storage     = 20
  max_allocated_storage = 100

  # HIPAA: Encryption at rest (required)
  storage_encrypted = true
  kms_key_id        = aws_kms_key.phi_data.arn

  # HIPAA: Encryption in transit (required)
  ca_cert_identifier = "rds-ca-rsa2048-g1"

  # HIPAA: Network isolation
  db_subnet_group_name   = aws_db_subnet_group.healthcare.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false  # NEVER expose to internet

  # HIPAA: Automated backups with encryption
  backup_retention_period = 30  # 30 days minimum for HIPAA
  backup_window          = "03:00-04:00"
  maintenance_window     = "mon:04:00-mon:05:00"
  
  # HIPAA: Enable deletion protection
  deletion_protection = true
  
  # HIPAA: Enable audit logging
  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  # HIPAA: Multi-AZ for high availability
  multi_az = true

  tags = {
    HIPAA = "true"
    PHI   = "true"
  }
}

# KMS Key for database encryption
resource "aws_kms_key" "phi_data" {
  description             = "KMS key for PHI data encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true  # HIPAA: Automatic key rotation

  tags = {
    HIPAA = "true"
    PHI   = "true"
  }
}
```

**Cost:** 
- db.t3.micro Multi-AZ: ~$30/month (750 hours free tier first year)
- KMS: $1/month + $0.03 per 10k requests

### 1.5 AWS WAF (Web Application Firewall)
**Problem:** No protection against SQL injection, XSS, DDoS attacks.

**Solution:** Deploy AWS WAF on CloudFront.

```hcl
# infra/waf.tf
resource "aws_wafv2_web_acl" "healthcare_api" {
  name  = "healthcare-api-waf"
  scope = "CLOUDFRONT"

  default_action {
    allow {}
  }

  # HIPAA: Rate limiting (prevent abuse)
  rule {
    name     = "rate-limit"
    priority = 1

    statement {
      rate_based_statement {
        limit              = 2000  # 2000 requests per 5 minutes per IP
        aggregate_key_type = "IP"
      }
    }

    action {
      block {}
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "RateLimit"
      sampled_requests_enabled   = true
    }
  }

  # AWS Managed Rules - Core Rule Set (SQL injection, XSS protection)
  rule {
    name     = "aws-managed-core-rules"
    priority = 2

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesCommonRuleSet"
      sampled_requests_enabled   = true
    }
  }

  # AWS Managed Rules - Known Bad Inputs
  rule {
    name     = "aws-managed-known-bad-inputs"
    priority = 3

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesKnownBadInputsRuleSet"
      sampled_requests_enabled   = true
    }
  }

  # Geographic restriction (US only for healthcare)
  rule {
    name     = "geo-restriction"
    priority = 4

    statement {
      not_statement {
        statement {
          geo_match_statement {
            country_codes = ["US"]
          }
        }
      }
    }

    action {
      block {}
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "GeoRestriction"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "HealthcareAPIWAF"
    sampled_requests_enabled   = true
  }

  tags = {
    HIPAA = "true"
  }
}

# Associate WAF with CloudFront
resource "aws_wafv2_web_acl_association" "cloudfront" {
  resource_arn = aws_cloudfront_distribution.api.arn
  web_acl_arn  = aws_wafv2_web_acl.healthcare_api.arn
}
```

**Cost:** 
- Web ACL: $5/month
- Rules: $1/month per rule (4 rules = $4/month)
- Requests: $0.60 per 1M requests
- **Total:** ~$9-10/month

### 1.6 Comprehensive Audit Logging (CloudTrail + CloudWatch)
**Problem:** Limited audit trails, cannot track "who accessed what PHI when".

**Solution:** Enable CloudTrail with S3 logging + CloudWatch Logs Insights.

```hcl
# infra/logging.tf
resource "aws_cloudtrail" "healthcare_audit" {
  name                          = "healthcare-audit-trail"
  s3_bucket_name                = aws_s3_bucket.audit_logs.id
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_log_file_validation    = true  # HIPAA: Tamper detection

  # HIPAA: Log to CloudWatch for real-time monitoring
  cloud_watch_logs_group_arn = "${aws_cloudwatch_log_group.cloudtrail.arn}:*"
  cloud_watch_logs_role_arn  = aws_iam_role.cloudtrail_cloudwatch.arn

  # HIPAA: Advanced event selectors for data events
  advanced_event_selector {
    name = "Log all S3 data events"
    field_selector {
      field  = "resources.type"
      equals = ["AWS::S3::Object"]
    }
  }

  advanced_event_selector {
    name = "Log all Lambda data events"
    field_selector {
      field  = "resources.type"
      equals = ["AWS::Lambda::Function"]
    }
  }

  tags = {
    HIPAA = "true"
  }
}

# S3 bucket for audit logs (encrypted, versioned, lifecycle)
resource "aws_s3_bucket" "audit_logs" {
  bucket = "healthcare-audit-logs-${data.aws_caller_identity.current.account_id}"

  tags = {
    HIPAA = "true"
  }
}

resource "aws_s3_bucket_versioning" "audit_logs" {
  bucket = aws_s3_bucket.audit_logs.id
  versioning_configuration {
    status = "Enabled"  # HIPAA: Version all logs
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "audit_logs" {
  bucket = aws_s3_bucket.audit_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.audit_logs.arn
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "audit_logs" {
  bucket = aws_s3_bucket.audit_logs.id

  rule {
    id     = "retain-logs"
    status = "Enabled"

    transition {
      days          = 90
      storage_class = "GLACIER"  # Archive after 90 days
    }

    expiration {
      days = 2555  # 7 years (HIPAA retention requirement)
    }
  }
}

# CloudWatch Log Group for real-time monitoring
resource "aws_cloudwatch_log_group" "cloudtrail" {
  name              = "/aws/cloudtrail/healthcare"
  retention_in_days = 2555  # 7 years

  kms_key_id = aws_kms_key.audit_logs.arn

  tags = {
    HIPAA = "true"
  }
}

# CloudWatch Alarms for HIPAA breach detection
resource "aws_cloudwatch_metric_alarm" "unauthorized_api_calls" {
  alarm_name          = "hipaa-unauthorized-api-calls"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "UnauthorizedAPICalls"
  namespace           = "CloudTrailMetrics"
  period              = 300
  statistic           = "Sum"
  threshold           = 5
  alarm_description   = "HIPAA: Alert on unauthorized API calls"
  alarm_actions       = [aws_sns_topic.security_alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "root_account_usage" {
  alarm_name          = "hipaa-root-account-usage"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "RootAccountUsage"
  namespace           = "CloudTrailMetrics"
  period              = 60
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "HIPAA: Alert on root account usage"
  alarm_actions       = [aws_sns_topic.security_alerts.arn]
}

# SNS Topic for security alerts
resource "aws_sns_topic" "security_alerts" {
  name              = "healthcare-security-alerts"
  kms_master_key_id = aws_kms_key.audit_logs.arn

  tags = {
    HIPAA = "true"
  }
}
```

**Cost:** 
- CloudTrail: $2 per 100k events
- S3 storage: ~$0.50/month (first year)
- CloudWatch Logs: Covered under free tier
- **Total:** ~$2-3/month

### 1.7 API Gateway Logging & Request Validation
**Current Gap:** No API Gateway request/response logging.

```yaml
# serverless.yml updates
functions:
  api:
    events:
      - http:
          path: /{proxy+}
          method: ANY
          cors: true
          authorizer:
            type: COGNITO_USER_POOLS
            authorizerId:
              Ref: ApiGatewayAuthorizer
          request:
            parameters:
              headers:
                Authorization: true  # Require auth header
```

**Add to serverless.yml:**
```yaml
provider:
  logs:
    restApi:
      accessLogging: true
      executionLogging: true
      level: INFO
      fullExecutionData: true
  tracing:
    apiGateway: true
    lambda: true  # X-Ray tracing for PHI access tracking
```

**Cost:** X-Ray tracing: $5 per 1M traces (first 100k free/month)

---

## 🤖 PHASE 2: HIPAA-ELIGIBLE AI/ML SERVICES

All AI services listed are **covered under AWS BAA** when properly configured.

### 2.1 Amazon Bedrock (Generative AI - Recommended)
**Use Cases:**
- Clinical documentation generation
- Patient communication drafting
- Medical coding assistance
- Summarization of patient records

**HIPAA Considerations:**
- ✅ Covered under AWS BAA
- ✅ Data not used for model training
- ✅ Supports VPC endpoints (no internet egress)
- ✅ Encryption in transit/rest

**Implementation:**
```python
# app/services/ai_service.py
import boto3
import json

class HealthcareAIService:
    def __init__(self):
        self.bedrock = boto3.client(
            'bedrock-runtime',
            region_name='us-east-1'
        )
    
    def generate_clinical_summary(self, patient_notes: str) -> str:
        """
        Generate clinical summary from patient notes using Claude.
        """
        prompt = f"""You are a medical documentation assistant. 
        Summarize the following patient notes in a structured clinical format:

        {patient_notes}

        Provide: Chief Complaint, History, Assessment, Plan (CHAP format)."""
        
        body = json.dumps({
            "prompt": f"\n\nHuman: {prompt}\n\nAssistant:",
            "max_tokens_to_sample": 1024,
            "temperature": 0.3,  # Low temperature for medical accuracy
            "top_p": 0.9,
        })
        
        response = self.bedrock.invoke_model(
            modelId='anthropic.claude-v2:1',  # HIPAA-eligible model
            body=body
        )
        
        response_body = json.loads(response['body'].read())
        return response_body['completion']
```

**Terraform Configuration:**
```hcl
# infra/bedrock.tf
resource "aws_bedrock_model_invocation_logging_configuration" "healthcare" {
  logging_config {
    embedding_data_delivery_enabled = true
    image_data_delivery_enabled     = true
    text_data_delivery_enabled      = true

    cloudwatch_config {
      log_group_name = aws_cloudwatch_log_group.bedrock.name
      role_arn       = aws_iam_role.bedrock_logging.arn
    }

    s3_config {
      bucket_name = aws_s3_bucket.bedrock_logs.id
      key_prefix  = "bedrock-logs/"
    }
  }
}

# VPC Endpoint for Bedrock (PHI never leaves AWS network)
resource "aws_vpc_endpoint" "bedrock_runtime" {
  vpc_id              = aws_vpc.healthcare.id
  service_name        = "com.amazonaws.us-east-1.bedrock-runtime"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.bedrock.id]
  private_dns_enabled = true

  tags = {
    Name  = "bedrock-runtime-endpoint"
    HIPAA = "true"
  }
}
```

**Cost:**
- Claude 2.1: $8 per 1M input tokens, $24 per 1M output tokens
- Typical clinical summary (500 input + 300 output): ~$0.01 per request
- 10k summaries/month: ~$100/month

### 2.2 Amazon Comprehend Medical
**Use Cases:**
- Extract medical entities (medications, conditions, procedures)
- Detect PHI in unstructured text (de-identification)
- ICD-10 / RxNorm code extraction
- Clinical trial matching

**HIPAA Features:**
- ✅ BAA-eligible
- ✅ HIPAA-specific API (DetectPHI)
- ✅ On-demand and batch processing

**Implementation:**
```python
# app/services/comprehend_medical.py
import boto3

class MedicalNLPService:
    def __init__(self):
        self.comprehend_medical = boto3.client(
            'comprehendmedical',
            region_name='us-east-1'
        )
    
    def extract_medical_entities(self, clinical_text: str) -> dict:
        """
        Extract medications, conditions, procedures from clinical text.
        """
        response = self.comprehend_medical.detect_entities_v2(
            Text=clinical_text
        )
        
        entities = {
            'medications': [],
            'conditions': [],
            'procedures': []
        }
        
        for entity in response['Entities']:
            if entity['Category'] == 'MEDICATION':
                entities['medications'].append({
                    'text': entity['Text'],
                    'score': entity['Score'],
                    'rxnorm_codes': [
                        attr['RxNormConcepts'] 
                        for attr in entity.get('Attributes', [])
                        if 'RxNormConcepts' in attr
                    ]
                })
            elif entity['Category'] == 'MEDICAL_CONDITION':
                entities['conditions'].append({
                    'text': entity['Text'],
                    'score': entity['Score'],
                    'icd10_codes': [
                        attr['ICD10CMConcepts']
                        for attr in entity.get('Attributes', [])
                        if 'ICD10CMConcepts' in attr
                    ]
                })
            elif entity['Category'] == 'PROCEDURE':
                entities['procedures'].append({
                    'text': entity['Text'],
                    'score': entity['Score']
                })
        
        return entities
    
    def detect_phi(self, text: str) -> dict:
        """
        Detect PHI in text for de-identification.
        """
        response = self.comprehend_medical.detect_phi(Text=text)
        
        phi_entities = []
        for entity in response['Entities']:
            phi_entities.append({
                'type': entity['Type'],  # NAME, ADDRESS, AGE, ID, etc.
                'text': entity['Text'],
                'score': entity['Score'],
                'begin_offset': entity['BeginOffset'],
                'end_offset': entity['EndOffset']
            })
        
        return phi_entities
```

**Cost:**
- DetectEntities: $0.01 per 100 characters
- DetectPHI: $0.01 per 100 characters
- InferICD10CM: $0.01 per 100 characters
- 1000 documents × 1000 chars: ~$100/month

### 2.3 Amazon Textract (Medical Document Processing)
**Use Cases:**
- Extract text from scanned medical records
- Process insurance forms
- Digitize handwritten prescriptions

**Implementation:**
```python
# app/services/document_processing.py
import boto3

class MedicalDocumentProcessor:
    def __init__(self):
        self.textract = boto3.client('textract', region_name='us-east-1')
    
    def process_medical_document(self, s3_bucket: str, s3_key: str) -> dict:
        """
        Extract text and forms from medical documents.
        """
        response = self.textract.analyze_document(
            Document={
                'S3Object': {
                    'Bucket': s3_bucket,
                    'Name': s3_key
                }
            },
            FeatureTypes=['FORMS', 'TABLES']
        )
        
        # Parse forms (key-value pairs)
        forms = {}
        for block in response['Blocks']:
            if block['BlockType'] == 'KEY_VALUE_SET':
                if 'KEY' in block['EntityTypes']:
                    key = self._get_text(block, response['Blocks'])
                    value = self._get_value(block, response['Blocks'])
                    forms[key] = value
        
        return {
            'full_text': self._get_full_text(response['Blocks']),
            'forms': forms,
            'tables': self._parse_tables(response['Blocks'])
        }
```

**Cost:** $0.05 per page (first 1M pages: $0.015/page)

### 2.4 Amazon SageMaker (Custom ML Models)
**Use Cases:**
- Patient readmission prediction
- Disease risk scoring
- Medical image analysis (X-rays, MRIs)
- Predictive analytics

**HIPAA Requirements:**
- ✅ Deploy in VPC
- ✅ Enable encryption for training data
- ✅ Use encrypted S3 buckets

**Example: Patient Readmission Model:**
```python
# app/services/ml_predictions.py
import boto3
import json

class HealthcarePredictions:
    def __init__(self):
        self.sagemaker_runtime = boto3.client(
            'sagemaker-runtime',
            region_name='us-east-1'
        )
        self.endpoint_name = 'readmission-prediction-endpoint'
    
    def predict_readmission_risk(self, patient_data: dict) -> dict:
        """
        Predict 30-day readmission risk.
        
        Args:
            patient_data: {
                'age': int,
                'diagnosis_codes': list,
                'length_of_stay': int,
                'num_medications': int,
                'num_procedures': int,
                'num_lab_procedures': int
            }
        """
        payload = json.dumps(patient_data)
        
        response = self.sagemaker_runtime.invoke_endpoint(
            EndpointName=self.endpoint_name,
            ContentType='application/json',
            Body=payload
        )
        
        result = json.loads(response['Body'].read().decode())
        
        return {
            'risk_score': result['predictions'][0],
            'risk_category': self._categorize_risk(result['predictions'][0]),
            'confidence': result['confidence']
        }
    
    def _categorize_risk(self, score: float) -> str:
        if score > 0.7:
            return 'HIGH'
        elif score > 0.4:
            return 'MEDIUM'
        else:
            return 'LOW'
```

**Cost:**
- Training: $0.05/hour (ml.m5.large)
- Inference endpoint: $0.096/hour (~$70/month for ml.t3.medium)
- Or use Serverless Inference (pay per invocation): $0.20 per 1k inferences

### 2.5 AWS HealthLake (FHIR-Native Data Store)
**Use Case:** Store and query healthcare data in FHIR format.

**Features:**
- ✅ Built-in HIPAA compliance
- ✅ FHIR R4 support
- ✅ Integrated NLP (powered by Comprehend Medical)
- ✅ SMART on FHIR support

**Cost:** $1.00 per GB stored/month + $0.30 per GB processed

**When to Use:** If you need FHIR interoperability with EHR systems.

---

## 📊 PHASE 3: ENHANCED MONITORING & COMPLIANCE

### 3.1 AWS Config (Continuous Compliance Monitoring)
**Purpose:** Automatically detect non-compliant resources.

```hcl
# infra/config.tf
resource "aws_config_configuration_recorder" "healthcare" {
  name     = "healthcare-config-recorder"
  role_arn = aws_iam_role.config.arn

  recording_group {
    all_supported                 = true
    include_global_resource_types = true
  }
}

# HIPAA Conformance Pack
resource "aws_config_conformance_pack" "hipaa" {
  name = "hipaa-compliance"

  template_body = file("${path.module}/conformance-packs/hipaa.yaml")
}

# Custom Config Rules
resource "aws_config_config_rule" "encrypted_volumes" {
  name = "encrypted-volumes"

  source {
    owner             = "AWS"
    source_identifier = "ENCRYPTED_VOLUMES"
  }
}

resource "aws_config_config_rule" "rds_encryption_enabled" {
  name = "rds-storage-encrypted"

  source {
    owner             = "AWS"
    source_identifier = "RDS_STORAGE_ENCRYPTED"
  }
}
```

**Cost:** $0.003 per configuration item recorded (~$2-5/month for small infrastructure)

### 3.2 AWS Security Hub (Centralized Security Findings)
**Purpose:** Aggregate security findings from multiple services.

```hcl
# infra/security_hub.tf
resource "aws_securityhub_account" "main" {}

resource "aws_securityhub_standards_subscription" "hipaa" {
  depends_on    = [aws_securityhub_account.main]
  standards_arn = "arn:aws:securityhub:us-east-1::standards/aws-foundational-security-best-practices/v/1.0.0"
}

# Enable integrations
resource "aws_securityhub_product_subscription" "guardduty" {
  depends_on  = [aws_securityhub_account.main]
  product_arn = "arn:aws:securityhub:us-east-1::product/aws/guardduty"
}

resource "aws_securityhub_product_subscription" "inspector" {
  depends_on  = [aws_securityhub_account.main]
  product_arn = "arn:aws:securityhub:us-east-1::product/aws/inspector"
}
```

**Cost:** $0.0010 per security check (~$10-15/month)

### 3.3 Amazon GuardDuty (Threat Detection)
**Purpose:** Detect compromised credentials, unusual API calls, malware.

```hcl
resource "aws_guardduty_detector" "main" {
  enable = true

  datasources {
    s3_logs {
      enable = true
    }
    kubernetes {
      audit_logs {
        enable = true
      }
    }
    malware_protection {
      scan_ec2_instance_with_findings {
        ebs_volumes {
          enable = true
        }
      }
    }
  }
}
```

**Cost:** $4.42 per 1M CloudTrail events analyzed (~$5-10/month)

---

## 💰 UPDATED COST ESTIMATE (HIPAA-Compliant + AI)

### Minimal Setup (Development - 50k requests/month)
| Service | Monthly Cost |
|---------|-------------|
| **Phase 1: HIPAA Compliance** | |
| Lambda (512MB) | $0.00 (free tier) |
| API Gateway | $0.18 |
| CloudFront | $0.00 (free tier) |
| Cognito (50 MAUs) | $0.00 (free tier) |
| RDS db.t3.micro Multi-AZ | $30.00 |
| VPC Endpoints | $7.00 |
| AWS WAF | $9.50 |
| CloudTrail + S3 logs | $2.50 |
| KMS keys (2 keys) | $2.00 |
| **Phase 1 Subtotal** | **$51.18/month** |
| | |
| **Phase 2: AI Services (Optional)** | |
| Bedrock (1k summaries/month) | $10.00 |
| Comprehend Medical (5k docs) | $50.00 |
| Textract (500 pages/month) | $7.50 |
| SageMaker Serverless Inference | $5.00 |
| **Phase 2 Subtotal** | **$72.50/month** |
| | |
| **Phase 3: Monitoring (Recommended)** | |
| AWS Config | $3.00 |
| Security Hub | $12.00 |
| GuardDuty | $8.00 |
| **Phase 3 Subtotal** | **$23.00/month** |
| | |
| **TOTAL (All Phases)** | **$146.68/month** |
| **TOTAL (Phase 1 only - Min HIPAA)** | **$51.18/month** |

### Medium Production (200k requests/month + AI)
| Component | Cost |
|-----------|------|
| Phase 1 (HIPAA) | $55.00 |
| RDS db.t3.small Multi-AZ | $60.00 |
| Bedrock (10k summaries) | $100.00 |
| Comprehend Medical (20k docs) | $200.00 |
| Phase 3 (Monitoring) | $25.00 |
| **TOTAL** | **$440/month** |

---

## 🚀 IMPLEMENTATION ROADMAP

### Week 1-2: Critical HIPAA Foundations
- [ ] **Day 1:** Request AWS BAA (Support ticket)
- [ ] **Day 2-3:** Create VPC + private subnets + security groups
- [ ] **Day 4-5:** Deploy RDS PostgreSQL with encryption
- [ ] **Day 6-7:** Implement Cognito authentication
- [ ] **Week 2:** Enable CloudTrail, Config, Security Hub

**Deliverable:** HIPAA-compliant infrastructure foundation

### Week 3-4: Security Hardening
- [ ] Deploy AWS WAF with managed rules
- [ ] Implement API Gateway authorizers
- [ ] Enable X-Ray tracing
- [ ] Configure CloudWatch alarms
- [ ] Update Lambda to VPC deployment

**Deliverable:** Secured API with authentication & monitoring

### Week 5-6: AI Integration (Optional)
- [ ] Set up Bedrock with VPC endpoints
- [ ] Implement clinical documentation AI features
- [ ] Deploy Comprehend Medical for entity extraction
- [ ] Create SageMaker model for predictions

**Deliverable:** AI-powered healthcare features

### Week 7-8: Compliance Validation
- [ ] Run AWS Config compliance checks
- [ ] Security Hub vulnerability scan
- [ ] Penetration testing (required for HIPAA)
- [ ] Document security controls
- [ ] Create incident response playbook

**Deliverable:** HIPAA compliance documentation

---

## 📋 HIPAA DOCUMENTATION REQUIREMENTS

### Required Policies & Procedures
1. **Security Policies**
   - Access control policy
   - Encryption policy
   - Incident response plan
   - Breach notification procedure

2. **Technical Documentation**
   - Network diagrams with data flows
   - Encryption implementation details
   - Audit log retention policies
   - Backup and disaster recovery procedures

3. **Training & Awareness**
   - HIPAA training for all developers
   - Security awareness program
   - Phishing prevention training

4. **Risk Assessment**
   - Annual HIPAA risk assessment
   - Threat modeling
   - Vulnerability scanning

### Compliance Checklist
```markdown
## HIPAA Technical Safeguards Checklist

### Access Control (45 CFR § 164.312(a)(1))
- [ ] Unique user IDs (Cognito)
- [ ] Multi-factor authentication (Cognito MFA)
- [ ] Automatic logoff (session timeout)
- [ ] Encryption and decryption (KMS)

### Audit Controls (45 CFR § 164.312(b))
- [ ] CloudTrail logging enabled
- [ ] CloudWatch Logs for API access
- [ ] 7-year log retention
- [ ] Tamper detection (log file validation)

### Integrity (45 CFR § 164.312(c)(1))
- [ ] Data integrity validation (checksums)
- [ ] Log file validation (CloudTrail)

### Transmission Security (45 CFR § 164.312(e)(1))
- [ ] TLS 1.2+ for all API endpoints
- [ ] VPC endpoints (no internet egress)
- [ ] Encrypted S3 buckets

### Physical Safeguards (AWS Responsibility)
- [x] AWS data center security (inherited)
- [x] Hardware disposal (AWS managed)
```

---

## ⚠️ CRITICAL WARNINGS

### 1. **DO NOT Process PHI Until BAA is Signed**
Without AWS BAA, you violate HIPAA regulations. Fines: $100 - $50,000 per violation, up to $1.5M per year.

### 2. **Do Not Use These AWS Services (NOT BAA-Eligible):**
- ❌ Amazon Mechanical Turk
- ❌ AWS DeepLens
- ❌ Amazon Sumerian
- ❌ AWS Elemental MediaConnect (some features)

### 3. **Lambda in VPC Considerations**
- Cold start latency increases (add 1-3 seconds)
- Requires NAT Gateway for internet access (~$32/month)
- Use VPC endpoints instead of NAT Gateway when possible

### 4. **Cost Control**
- Set AWS Budgets alerts at $50, $100, $200
- Enable Cost Anomaly Detection
- Use Bedrock on-demand pricing initially (not Provisioned Throughput)

---

## 📚 NEXT STEPS

### Immediate Actions (This Week)
1. **Request AWS BAA** via Support Console
2. **Review with legal/compliance team** - ensure internal HIPAA policies exist
3. **Prioritize Phase 1** - Do not proceed with AI until Phase 1 is complete
4. **Budget approval** - Secure $50-150/month budget

### Technical Implementation (After BAA)
1. Create new branch: `feature/hipaa-compliance`
2. Start with VPC setup (lowest risk change)
3. Implement changes incrementally with testing
4. Use Terraform workspaces for staging environment

### Questions to Answer
- **Q:** Do you have existing HIPAA compliance program?
- **Q:** Do you need FHIR interoperability (HealthLake)?
- **Q:** What specific AI use cases are highest priority?
- **Q:** Do you have a HIPAA compliance officer?

---

## 🔗 RESOURCES

### AWS Documentation
- [HIPAA Compliance on AWS](https://aws.amazon.com/compliance/hipaa-compliance/)
- [AWS BAA Request Process](https://aws.amazon.com/artifact/)
- [HIPAA Eligible Services](https://aws.amazon.com/compliance/hipaa-eligible-services-reference/)
- [Bedrock HIPAA Guide](https://docs.aws.amazon.com/bedrock/latest/userguide/security-compliance.html)

### Implementation Guides
- [AWS HIPAA Reference Architecture](https://github.com/aws-samples/aws-hipaa-reference-architecture)
- [Serverless HIPAA on AWS](https://aws.amazon.com/blogs/industries/serverless-applications-for-healthcare/)

### Compliance Training
- [HHS HIPAA Training](https://www.hhs.gov/hipaa/for-professionals/training/index.html)
- [AWS Well-Architected Healthcare Lens](https://docs.aws.amazon.com/wellarchitected/latest/healthcare-industry-lens/)

---

**Document Version:** 1.0  
**Last Updated:** November 29, 2025  
**Author:** GitHub Copilot (Claude Sonnet 4.5)  
**Status:** ⚠️ DRAFT - Requires Legal Review
