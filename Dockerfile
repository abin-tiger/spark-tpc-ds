ARG base_img=public.ecr.aws/b7p5s1z2/spark:latest

FROM amazonlinux:2 as tpc-toolkit

RUN yum group install -y "Development Tools" && \
    git clone https://github.com/databricks/tpcds-kit.git -b master /tmp/tpcds-kit && \
    cd /tmp/tpcds-kit/tools && \
    make OS=LINUX

FROM mozilla/sbt:8u292_1.5.4 as sbt

ARG SPARK_VERSION=3.1.2

# Build the Databricks SQL perf library
RUN git clone https://github.com/abin-tiger/spark-sql-perf.git -b spark-${SPARK_VERSION} /tmp/spark-sql-perf && \
    cd /tmp/spark-sql-perf/ && \
    sbt +package

# Use the compiled Databricks SQL perf library to build eks-spark-benchmark
RUN git clone https://github.com/abin-tiger/eks-spark-benchmark.git -b spark-${SPARK_VERSION} /tmp/eks-spark-benchmark \
    && cd /tmp/eks-spark-benchmark/ && mkdir /tmp/eks-spark-benchmark/benchmark/libs \
    && cp /tmp/spark-sql-perf/target/scala-2.12/*.jar /tmp/eks-spark-benchmark/benchmark/libs \
    && cd /tmp/eks-spark-benchmark/benchmark && sbt assembly

FROM ${base_img}

ADD https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-bundle/1.11.874/aws-java-sdk-bundle-1.11.874.jar ${SPARK_HOME}/jars
ADD https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-aws/3.2.0/hadoop-aws-3.2.0.jar ${SPARK_HOME}/jars

# Copy tpcds-kit and eks-spark-benchmark library
COPY --from=tpc-toolkit /tmp/tpcds-kit/tools /opt/tpcds-kit/tools
COPY --from=sbt /tmp/eks-spark-benchmark/benchmark/target/scala-2.12/*jar ${SPARK_HOME}/examples/jars/
