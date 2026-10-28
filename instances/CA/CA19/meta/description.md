# .NET 3.5 configuration initialization failure

Running the application fails with `Configuration system failed to initialize`. The inner error says:

```
Unrecognized configuration section userSettings
```

The failure occurs when the application reads its settings from the executable configuration file. Diagnose the configuration and make the application start normally without changing the application binary.
