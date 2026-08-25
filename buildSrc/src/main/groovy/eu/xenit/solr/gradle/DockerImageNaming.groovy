package eu.xenit.solr.gradle

import be.vbgn.gradle.cidetect.CiInformation

/**
 * Derives the repository and tags of the images we publish.
 */
class DockerImageNaming {

    static String repository(String flavor, boolean enterprise, boolean customized) {
        def repoName = enterprise ? "docker.xenit.eu/alfresco-enterprise" : "docker.io/xenit"
        return customized ? "${repoName}/alfresco-${flavor}-xenit" : "${repoName}/alfresco-${flavor}"
    }

    static List<String> tags(version) {
        // detect() reads only the environment, so it needs no Project and is cheap enough to redo per project
        def ci = CiInformation.detect()

        def tags = [
                "${version.major}.${version.minor}.${version.rev}".toString(),
                "${version.major}.${version.minor}".toString()
        ]

        if (version.maint) {
            tags += "${version.major}.${version.minor}.${version.rev}.${version.maint}".toString()
        }
        if (version.label) {
            tags += "${version.major}.${version.minor}.${version.rev}.${version.label}".toString()
            if (version.maint) {
                tags += "${version.major}.${version.minor}.${version.rev}.${version.maint}.${version.label}".toString()
            }
        }
        // For non-master/non-release builds, change the tags to contain branch and build number
        def isTestBuild = ci.isCi() && ci.branch != "master" && ci.branch != "release"
        if (isTestBuild) {
            tags = tags.collect { "${it}-build-${ci.buildNumber}".toString() }
        }

        return tags
    }
}
