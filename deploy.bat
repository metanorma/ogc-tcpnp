:: TODO: replace this script when https://github.com/travis-ci/dpl/issues/694 is fixed
:: Revriten based on https://raw.githubusercontent.com/w3c/permissions/master/deploy.sh

SET SOURCE_BRANCH="master"
SET TARGET_BRANCH="gh-pages"
SET KEY_NAME=%CD%\deploy_key

:: Pull requests and commits to other branches shouldn't try to deploy, just build to verify
if "%TRAVIS_PULL_REQUEST%" NEQ "false" goto SkipDeploy
if "%TRAVIS_BRANCH%" NEQ "%SOURCE_BRANCH%" goto SkipDeploy

goto Deploy

:SkipDeploy
ECHO Not a Travis PR or not matching branch %SOURCE_BRANCH%; skipping deploy.
EXIT /B 0

:Deploy

IF "%COMMIT_AUTHOR_EMAIL%"=="" (
  ECHO [%~dpnx0] No COMMIT_AUTHOR_EMAIL provided; it must be set. 1>&2
  EXIT /B 1
)

IF NOT EXIST %KEY_NAME% (
  ECHO [%~dpnx0] No %KEY_NAME% file detected; is %KEY_NAME%.enc decrypted? 1>&2
  EXIT /B 1
)

:: Save some useful information
git config remote.origin.url > REPO.var
SET /p REPO=<REPO.var
CALL SET SSH_REPO=%%REPO:https^://github.com/^=git@github.com:%%
git rev-parse --verify HEAD > SHA.var
SET /p SHA=<SHA.var
SET DEST_DIR=out

:: Clone the existing %TARGET_BRANCH% for this repo into %DEST_DIR%\
:: Create a new empty branch if gh-pages doesn't exist yet (should only happen on first deploy)
git clone %REPO% %DEST_DIR% | ECHO [%~dpnx0] Unable to clone Git. 1>&2 & EXIT /B 1
PUSHD %DEST_DIR%
git checkout %TARGET_BRANCH% | git checkout --orphan %TARGET_BRANCH% | errx ECHO [%~dpnx0] Unable to checkout git. 1>&2 & EXIT /B 1
POPD

:: Clean out existing contents in %TARGET_BRANCH% clone
rm -rf %DEST_DIR%\* | EXIT /B 0

:: Adding contents within published/ to %DEST_DIR%
cp -a published/* %DEST_DIR%\ | EXIT /B 0

:: Now let's go have some fun with the cloned repo
PUSHD %DEST_DIR%
git config user.name "Travis CI"
git config user.email "%COMMIT_AUTHOR_EMAIL%"

:: If there are no changes to the compiled out (e.g. this is a README update) then just bail.
git diff --exit-code
IF "%ERRORLEVEL%"=="0" (
  ECHO No changes to the output on this push; exiting.
  EXIT 0
)

git status

:: Commit the "changes", i.e. the new version.
:: The delta will show diffs between new and old versions.
git add .
git commit -m "Deploy to GitHub Pages: %SHA%"

start-ssh-agent
ssh-add %KEY_NAME%

:: Now that we're all set up, we can push.
git push %SSH_REPO% %TARGET_BRANCH% | ECHO "Unable to push to git." 1>&2 & EXIT /B 1
POPD

exit 0
