export default {
  build: {
    tasks: {
      assembleApp: {
        description: 'Assemble the application',
        dependsOn: ['entry:assembleHap']
      }
    }
  }
}
