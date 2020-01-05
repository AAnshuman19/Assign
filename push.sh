echo "********************"
echo "** Pushing image ***"
echo "********************"

IMAGE="maven-project"

echo "** Logging in ***"
docker login -u abhi -p $PASS
echo "*** Tagging image ***"
docker tag $IMAGE:$BUILD_TAG abhi/$IMAGE:$BUILD_TAG
echo "*** Pushing image ***"
docker push abhi/$IMAGE:$BUILD_TAG
