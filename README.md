# OAS Generator Archetype

This project aims to provide a Maven archetype that creates a project with the needed configuration for Java stub generation from a specified [OAS](https://swagger.io/specification/) 3(Open Api Specification).

## Before all

You must set a settings.xml for Maven where the repo:

````
<repositories>
    <repository>
        <id>github</id>
        <url>https://maven.pkg.github.com/txomin55/k9x-oas-generator-archetype</url>
    </repository>
</repositories>
````

## Usage

First, the dependency must be downloaded :

- <code>mvn dependency:get -Dartifact=com.obdx.oas-generator-archetype:oas-generator-archetype:$OBDX_OAS_GENERATOR_ARCHETYPE_PROJECT_VERSION -DremoteRepositories=github::::https://maven.pkg.github.com/txomin55/k9x-oas-generator-archetype -s ci_settings.xml</code>

Then, the archetype catalogue must be updated:

- <code>mvn -f .m2/repository/com/obdx/oas-generator-archetype/oas-generator-archetype/$OBDX_OAS_GENERATOR_ARCHETYPE_PROJECT_VERSION/oas-generator-archetype-$OBDX_OAS_GENERATOR_ARCHETYPE_PROJECT_VERSION.pom archetype:update-local-catalog -s ci_settings.xml</code>

Then, we can generate the project:

- <code>mvn archetype:generate -B -DarchetypeGroupId=com.obdx.oas-generator-archetype -DarchetypeArtifactId=oas-generator-archetype -DarchetypeVersion=$OBDX_OAS_GENERATOR_ARCHETYPE_PROJECT_VERSION -DgroupId=com.tmanager.generated-folder -DartifactId=generated-folder -Dname=generated-folder -DgithubRepo=txomin55/obdx-oas-generator-archetype -Dversion=0.0.1-SNAPSHOT -DinteractiveMode=false -s ci_settings.xml</code>

You must add an "openapi.yaml" file to the generated-folder and then finally run:

- <code>mvn -f generated-folder/pom.xml clean deploy -s generated-folder/ci_settings.xml</code>

*Must be taken into account that the generated "ci_settings.xml" file is prepared to be used in GitHub Actions, if used in local, there is no need of it.

### Local test script

To test the archetype locally (without GitHub registry), use:

- <code>./test-archetype-local.sh /path/to/openapi.yaml [archetype_version]</code>

Notes:
* If <code>archetype_version</code> is omitted, the script uses the version from this project's <code>pom.xml</code>.
* The generated project is created under a temporary folder inside this repo (e.g. <code>.archetype-test-XXXXXX/obdx-oas-definition</code>).
* The generated project targets Java 25. Ensure you run with a JDK 25 (e.g. set <code>JAVA_HOME</code> before running the script).

### Parameters

Apart from the mandatory Maven archetype <code>archetypeGroupId</code>, <code>archetypeArtifactId</code> and <code>archetypeVersion</code> related with a standard archetype, this archetype needs the following parameters:

* name: Generating project name
* githubRepo: GitHub repo in owner/repo format for GitHub Packages
* version: Generating project version

## Technical aspects

For the creation of this project instructions defined [here](https://rieckpil.de/create-your-own-maven-archetype-in-5-simple-steps/) where followed.

A Maven Archetype needs a pom.xml with a <code>maven-archetype</code> packaging and the Maven <code>archetype-packaging</code> extension. The structure of the project must follow Maven standard. So, under src/main/resources you set the root content of the project to be created, in this case, there can be find the <code>pom.xml</code> and the <code>ci_settings.xml</code>. Both have the filtering activated, so the parameters defined above are replaced by the assigned value.

An archetype also, is supposed to include a <code>archetype-metadata.xml</code> under META-INF/maven directory, and is there where all project parameters, files etc are included.

### Generated project

Once the <code>archetype:generate</code> command is executed, an empty Maven project will be generated, it expects a <code>openapi.yaml</code> OAS file in its root path.

It uses the <code>openapi-generator-maven-plugin</code> to generate all stubs (POJOs, Java interfaces...). The generator is Spring based, so all stubs have the Spring annotations. The configuration of the plugin is defined to create the so called "Delegate pattern" that creates an interface for each API to be implemented by the consumer, if not an exception is thrown in runtime, saying there is no implementation for it. Another important option is the <code>useTags</code> which creates a controller, delegate interface and API interface for each tag found in the OAS spec.

To generate all stub you only need to execute the following:

- <code>mvn clean install</code>

This will generate all needed files under /target folder.

In case you want to deploy your maven project as a dependency (in this case to GitHub Packages), you must run:

- <code>mvn clean build</code>

This will generate and upload the result to the defined registry inside the pom.xml under the <code>distributionManagement</code> option.
