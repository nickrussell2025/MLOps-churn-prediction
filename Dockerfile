FROM prefecthq/prefect:3.4.7-python3.12
COPY requirements.txt /opt/prefect/mlops-project/requirements.txt
RUN python -m pip install -r /opt/prefect/mlops-project/requirements.txt
COPY . /opt/prefect/mlops-project/
WORKDIR /opt/prefect/mlops-project/
