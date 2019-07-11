Package.describe({
  summary: "Reactive publish endpoints",
  version: '0.8.2',
  name: 'peerlibrary:reactive-publish',
  git: 'https://github.com/chungl/meteor-reactive-publish.git'
});

Package.onUse(function (api) {
  api.versionsFrom('METEOR@1.4.4.5');

  // Core dependencies.
  api.use([
    'coffeescript@2.0.3_3',
    'ecmascript',
    'mongo',
    'minimongo',
    'underscore'
  ], 'server');

  // 3rd party dependencies.
  api.use([
    'peerlibrary:server-autorun@0.7.1',
    'peerlibrary:reactive-mongo@0.3.0',
    'peerlibrary:extend-publish@0.5.0'
  ], 'server');

  api.addFiles([
    'server.coffee'
  ], 'server');
});

Package.onTest(function (api) {
  api.versionsFrom('METEOR@1.4.4.5');

  // Core dependencies.
  api.use([
    'coffeescript@2.0.3_3',
    'ecmascript',
    'insecure',
    'random',
    'underscore',
    'reactive-var',
    'check',
    'mongo'
  ]);

  // Internal dependencies.
  api.use([
    'peerlibrary:reactive-publish'
  ]);

  // 3rd party dependencies.
  api.use([
    'peerlibrary:assert@0.2.5',
    'peerlibrary:server-autorun@0.7.1',
    'peerlibrary:classy-test@0.3.0',
    'lamhieu:unblock@1.0.0'
  ]);

  api.add_files([
    'tests.coffee'
  ]);
});
