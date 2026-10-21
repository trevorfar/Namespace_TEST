# Custom base image for the Namespace "benchmark" runner profile.
# Bakes the heavy CI dependencies into the runner image so jobs don't depend
# on cache-volume placement. Applied with:
#   nsc github profile update --profile_id ghpf_al65pn8pl1ucu --dockerfile ci/runner.Dockerfile
# The image is only rebuilt when the profile is updated, so the workflow still
# runs `pip install -r requirements-ci.txt` against this venv to catch drift.
ARG NAMESPACE_BASE_IMAGE_REF=""
FROM ${NAMESPACE_BASE_IMAGE_REF} AS base

USER root
ADD https://raw.githubusercontent.com/trevorfar/Namespace_TEST/main/requirements-ci.txt /tmp/requirements-ci.txt
RUN python3 -m venv /opt/ci-venv \
    && /opt/ci-venv/bin/pip install --no-cache-dir -r /tmp/requirements-ci.txt \
    && chown -R runner:runner /opt/ci-venv \
    && rm /tmp/requirements-ci.txt

# GitHub's runner software must run as this user.
USER runner
