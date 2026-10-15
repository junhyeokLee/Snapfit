import { defineRailway, project, service } from 'railway/iac';

// New services use Railway IaC. No public repository, image registry, secrets,
// database, volume or public endpoint is declared by this worker configuration.
export default defineRailway(() => {
  const worker = service('snapfit-print-worker', {
    build: {
      builder: 'DOCKERFILE',
      dockerfilePath: 'Dockerfile',
    },
    deploy: {
      numReplicas: 1,
      region: 'asia-southeast1-eqsg3a',
      sleepApplication: false,
      restartPolicyType: 'ALWAYS',
      limitOverride: {
        containers: {
          cpu: 2,
          memoryBytes: 4 * 1024 * 1024 * 1024,
        },
      },
      overlapSeconds: 0,
      drainingSeconds: 30,
    },
  });

  return project('snapfit-print', { resources: [worker] });
});
