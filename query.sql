-- MySQL query
-- Copyright Huascar Sanchez, 2017.

-- V.0
-- SELECT DISTINCT
--     S1.GH_PROJECT_NAME,
--     S1.TR_BUILD_ID,
--     S1.GIT_COMMIT,
--     S1.TR_STATUS,
--     S1.TR_STARTED_AT,
--     S1.GH_LANG,
--     S1.GIT_BRANCH,
--     S1.TR_JOB_ID
-- FROM travistorrent_7_9_2016 S1
-- INNER JOIN (
--   SELECT GH_PROJECT_NAME
--   FROM travistorrent_7_9_2016
--   WHERE GH_LANG in ("ruby", "java")
--   GROUP BY GH_PROJECT_NAME
-- ) S2 ON S1.GH_PROJECT_NAME = S2.GH_PROJECT_NAME

-- V.1

SELECT 
		S1.GH_PROJECT_NAME AS GH_PROJECT_NAME, 
		S1.TR_BUILD_ID AS TR_BUILD_ID, 
    -- Timestamp of the push that triggered the build, in UTC. 
		S1.GH_BUILD_STARTED_AT AS GH_BUILD_STARTED_AT,
    -- The commit that triggered the build 
		S1.GIT_TRIGGER_COMMIT AS GIT_TRIGGER_COMMIT,
    -- A core team member is someone who's contributed at least once within 3 mons b4 this commit
    S1.GH_BY_CORE_TEAM_MEMBER AS GH_BY_CORE_TEAM_MEMBER,
    -- Number of developers that committed directly or merged PRs within 3 months
    S1.GH_TEAM_SIZE AS GH_TEAM_SIZE,
    -- Return build status (such as passed, failed, …)
		S1.TR_STATUS AS TR_STATUS,
    -- Return status of the build, extracted by build log analysis.
    S1.TR_LOG_STATUS AS TR_LOG_STATUS,
    -- Number of tests that failed
    IFNULL(S1.TR_LOG_NUM_TESTS_FAILED, 0) AS TR_LOG_NUM_TESTS_FAILED, 
    -- The primary programming language, according to Travis
    S1.TR_LOG_LAN AS TR_LOG_LAN,  
    -- The primary programming language, according to GitHub
    S1.GH_LANG AS GH_LANG,
    -- The branch that was built
		S1.GIT_BRANCH AS GIT_BRANCH,
    -- Whether this build was triggered as part of a pull request on GitHub
    S1.GH_IS_PR AS GH_IS_PR,
    -- how was this PR (if true) closed (e.g., merge button, manual merge, …)
    IFNULL(S1.GIT_MERGED_WITH, "unknown") AS GIT_MERGED_WITH,
    -- Return the number of comments in Pull Request
    IFNULL(S1.GH_NUM_PR_COMMENTS, 0 ) AS GH_NUM_PR_COMMENTS,
    -- Return the number of comments in Git Issue
    IFNULL(S1.GH_NUM_ISSUE_COMMENTS, 0) AS GH_NUM_ISSUE_COMMENTS,
    -- Return the number of comments in Git Issue
    IFNULL(S1.GH_NUM_COMMIT_COMMENTS, 0) AS GH_NUM_COMMIT_COMMENTS,
    -- The job id of the build job under analysis
		S1.TR_JOB_ID AS TR_JOB_ID
FROM [travistorrent-bq:data.2017_01_11] AS S1 
INNER JOIN (
	SELECT GH_PROJECT_NAME 
	FROM [travistorrent-bq:data.2017_01_11] 
	WHERE GH_LANG in ("java") AND GH_PROJECT_NAME in ("apache/cloudstack", "apache/commons-lang", "apache/cordova-android", "apache/drill", "apache/hive", "apache/jackrabbit-oak", "apache/libcloud", 
  "apache/mahout", "apache/nifi", "apache/parquet-mr", "apache/pdfbox", "apache/sling", "apache/tajo", "apache/zeppelin", "square/dagger", "square/javapoet", "square/keywhiz", "square/kochiku", 
  "square/leakcanary", "square/okio", "square/otto", "square/p2", "square/picasso", "square/tape", "square/wire", "Netflix/Hystrix", "Netflix/spectator", "google/cadvisor", "google/auto", 
  "google/ggrc-core", "google/git-appraise", "google/go-github", "google/gopacket", "google/grr", "google/guava", "google/guice", "google/gxui", "google/iosched", "google/oauth2client", 
  "google/physical-web", "google/yapf", "mongodb/mongo-java-driver", "twitter/commons", "twitter/heron")
	GROUP BY GH_PROJECT_NAME
) S2 ON S1.GH_PROJECT_NAME = S2.GH_PROJECT_NAME
LIMIT 16000