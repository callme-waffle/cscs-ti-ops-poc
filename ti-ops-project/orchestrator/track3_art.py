from kubernetes import client, config
import uuid

class Track3ART:
    def __init__(self):
        try:
            config.load_kube_config()
        except:
            config.load_incluster_config()
        self.batch_api = client.BatchV1Api()

    def run_simulation(self, t_id):
        print(f"   ⚔️ [Track 3] 공격 시뮬레이션 Job 생성: {t_id}")
        job_name = f"art-sim-{t_id.lower()}-{uuid.uuid4().hex[:6]}"
        
        job = client.V1Job(
            api_version="batch/v1",
            kind="Job",
            metadata=client.V1ObjectMeta(name=job_name),
            spec=client.V1JobSpec(
                template=client.V1PodTemplateSpec(
                    spec=client.V1PodSpec(
                        restart_policy="Never",
                        containers=[
                            client.V1Container(
                                name="art",
                                image="alpine",
                                command=["/bin/sh", "-c"],
                                args=[f"echo '🔥 Simulating {t_id}...'; sleep 2; echo '✅ Done'"]
                            )
                        ]
                    )
                ),
                ttl_seconds_after_finished=60
            )
        )
        try:
            self.batch_api.create_namespaced_job("default", job)
            print(f"   🚀 Job 실행됨: {job_name}")
        except Exception as e:
            print(f"   ❌ Job 생성 실패: {e}")
