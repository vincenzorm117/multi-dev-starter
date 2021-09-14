const AWS = require("aws-sdk");
const cloudfront = new AWS.CloudFront();
const route53 = new AWS.Route53();

const UpdateCloudfront = async (config) => {
  // [Step] Get Distrubition info
  const params = await cloudfront
    .getDistributionConfig({ Id: config.cloudFrontDistributionId })
    .promise();

  // [Step] Set Id to DistributionId
  params.Id = config.cloudFrontDistributionId;

  // [Step] Set IfMatch to ETAG
  params.IfMatch = params.ETag;

  // [Step] Strip ETag
  delete params.ETag;

  // [Step] Update Aliases
  params.DistributionConfig.Aliases.Items.push(config.fullDomain);
  params.DistributionConfig.Aliases.Quantity += 1;

  // [Step] Update cloudfront
  return await cloudfront.updateDistribution(params).promise();
};

const UpdateRoute53 = async (config) => {
  const cloudfrontHostedZoneId = process.env.CLOUDFRONT_HOSTED_ZONE_ID;
  if (
    typeof cloudfrontHostedZoneId !== "string" ||
    cloudfrontHostedZoneId.length <= 0
  ) {
    throw new Error(
      `process.env.CLOUDFRONT_HOSTED_ZONE_ID is empty. Make the environment variable for it is set.`
    );
  }

  // [Step] Get cloudfront distribution
  const { Distribution } = await cloudfront
    .getDistribution({ Id: config.cloudFrontDistributionId })
    .promise();

  // [Step] Setup
  const params = {
    ChangeBatch: {
      Changes: [
        {
          Action: "CREATE",
          ResourceRecordSet: {
            AliasTarget: {
              DNSName: Distribution.DomainName,
              EvaluateTargetHealth: false,
              HostedZoneId: cloudfrontHostedZoneId,
            },
            Name: config.fullDomain,
            Type: "A",
          },
        },
      ],
      Comment: "CloudFront distribution for example.com",
    },
    HostedZoneId: config.domainHostedZoneId,
  };

  // [Step] Add A record to Route53
  return await route53.changeResourceRecordSets(params).promise();
};

const ExtractConfig = (event) => {
  const bucketName = event.Records[0].s3.bucket.name;
  const config = {};

  // [Step] Extract the branch name
  const regex = /^[^/]+/;
  config.branchName = event.Records[0].s3.object.key.match(regex)?.[0] ?? null;

  // [Step] Extract the Cloudfront Distribution Id
  let searchTerm = `cf-${bucketName}`;
  for (const [key, value] of Object.entries(process.env)) {
    if (value === searchTerm) {
      config.cloudFrontDistributionId = key;
      break;
    }
  }

  // [Step] Extract the Route53 Hosted Zone Id
  searchTerm = `hz-${bucketName}`;
  for (const [key, value] of Object.entries(process.env)) {
    if (value === searchTerm) {
      config.domainHostedZoneId = key;
      break;
    }
  }

  // [Step] Extract domain
  searchTerm = `dns-${bucketName}`;
  for (const [key, value] of Object.entries(process.env)) {
    if (value === searchTerm) {
      config.domain = key.replace(/_/g, ".");
      break;
    }
  }

  // [Step] Return
  if (
    [
      "branchName",
      "cloudFrontDistributionId",
      "domainHostedZoneId",
      "domain",
    ].every((k) => config.hasOwnProperty(k))
  ) {
    config.fullDomain = `${config.branchName}.${config.domain}`;
    return config;
  }
  return null;
};

const InvalidateCloudfront = (config) => {
  const params = {
    DistributionId: config.cloudFrontDistributionId,
    InvalidationBatch: {
      CallerReference: Date.now().toString(),
      Paths: {
        Quantity: 1,
        Items: [`/*`],
      },
    },
  };

  return cloudfront.createInvalidation(params).promise();
};

const WaitForInvalidation = (config, Invalidation) => {
  const params = {
    DistributionId: config.cloudFrontDistributionId,
    Id: Invalidation.Id,
  };
  return cloudfront.waitFor("invalidationCompleted", params).promise();
};

exports.handler = async (event) => {
  let res;
  const config = ExtractConfig(event);

  try {
    res = await UpdateRoute53(config);
  } catch (error) {
    // If error has "it already exists" it means the A record already exists
    //   thus we dont need to stop the program here.
    const regex = /it already exists/;
    if (!regex.test(error.message)) {
      console.error(error);
      return;
    }
  }

  try {
    res = await UpdateCloudfront(config);
  } catch (error) {
    console.error(error);
  }

  try {
    res = await InvalidateCloudfront(config);
    res = await WaitForInvalidation(config, res.Invalidation);
  } catch (error) {
    console.error(error);
  }
};
