using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SchoolService.API.Services;

namespace SchoolService.API.Controllers;

// Controller for monitoring health of services registered in Consul
// Useful for debugging and visibility into the microservice landscape
[ApiController]
[Authorize(Roles = "Admin")]
[Route("api/[controller]")]
public class ServiceHealthController : ControllerBase
{
    private readonly IServiceDiscoveryClient _serviceDiscovery;
    private readonly ILogger<ServiceHealthController> _logger;

    public ServiceHealthController(
        IServiceDiscoveryClient serviceDiscovery,
        ILogger<ServiceHealthController> logger)
    {
        _serviceDiscovery = serviceDiscovery;
        _logger = logger;
    }

    // Returns health status for every service Consul knows about, including instance counts
    [HttpGet("dashboard")]
    public async Task<IActionResult> GetServicesDashboard()
    {
        _logger.LogInformation("Fetching services health dashboard from Consul...");
        
        var servicesHealth = await _serviceDiscovery.GetAllServicesHealthAsync();
        
        var dashboard = new
        {
            timestamp = DateTime.UtcNow,
            totalServices = servicesHealth.Count,
            services = servicesHealth.Values.Select(s => new
            {
                serviceName = s.ServiceName,
                status = s.IsHealthy ? "Healthy" : "Unhealthy",
                totalInstances = s.TotalInstances,
                healthyInstances = s.HealthyInstances,
                unhealthyInstances = s.UnhealthyInstances,
                instances = s.Instances.Select(i => new
                {
                    serviceId = i.ServiceId,
                    address = i.Address,
                    port = i.Port,
                    url = i.Url,
                    isHealthy = i.IsHealthy,
                    tags = i.Tags
                })
            }),
            summary = new
            {
                healthyServices = servicesHealth.Values.Count(s => s.IsHealthy),
                unhealthyServices = servicesHealth.Values.Count(s => !s.IsHealthy),
                totalInstances = servicesHealth.Values.Sum(s => s.TotalInstances),
                healthyInstances = servicesHealth.Values.Sum(s => s.HealthyInstances),
                unhealthyInstances = servicesHealth.Values.Sum(s => s.UnhealthyInstances)
            }
        };

        return Ok(dashboard);
    }

    // Returns all instances registered for the given service name
    [HttpGet("service/{serviceName}")]
    public async Task<IActionResult> GetServiceInstances(string serviceName)
    {
        _logger.LogInformation("Fetching instances for service: {ServiceName}", serviceName);
        
        var instances = await _serviceDiscovery.GetServiceInstancesAsync(serviceName);
        
        if (instances == null || instances.Count == 0)
        {
            return NotFound(new
            {
                error = "Service not found",
                serviceName,
                message = $"No healthy instances found for '{serviceName}' in Consul"
            });
        }

        return Ok(new
        {
            serviceName,
            instanceCount = instances.Count,
            instances = instances.Select(i => new
            {
                serviceId = i.ServiceId,
                address = i.Address,
                port = i.Port,
                url = i.Url,
                isHealthy = i.IsHealthy,
                tags = i.Tags,
                lastChecked = i.LastChecked
            }),
            loadBalancing = "Round-robin",
            caching = "30 seconds TTL"
        });
    }

    // Discovers a service URL through Consul - call multiple times to see round-robin selection
    [HttpGet("discover/{serviceName}")]
    public async Task<IActionResult> DiscoverService(string serviceName)
    {
        _logger.LogInformation("Discovering service: {ServiceName}", serviceName);
        
        var url = await _serviceDiscovery.GetServiceUrlAsync(serviceName);
        
        if (string.IsNullOrEmpty(url))
        {
            return NotFound(new
            {
                error = "Service not found",
                serviceName,
                message = $"Could not discover '{serviceName}' in Consul"
            });
        }

        return Ok(new
        {
            serviceName,
            selectedUrl = url,
            timestamp = DateTime.UtcNow,
            note = "Call this endpoint multiple times to see round-robin load balancing in action"
        });
    }

    // Quick ping to confirm this service is up and running
    [AllowAnonymous]
    [HttpGet("ping")]
    public IActionResult Ping()
    {
        return Ok(new
        {
            service = "school-service",
            status = "Healthy",
            timestamp = DateTime.UtcNow,
            consul = "Connected",
            features = new[]
            {
                "Service Discovery via Consul",
                "Round-robin Load Balancing",
                "Service Instance Caching (30s TTL)",
                "Health-aware Instance Selection",
                "Role-based Authorization via Auth-Service"
            }
        });
    }

    // Tests connectivity to auth-service by discovering it through Consul and calling its health endpoint
    [HttpGet("test-auth-connection")]
    public async Task<IActionResult> TestAuthServiceConnection()
    {
        _logger.LogInformation("Testing connection to auth-service via Consul...");
        
        var url = await _serviceDiscovery.GetServiceUrlAsync("auth-service");
        
        if (string.IsNullOrEmpty(url))
        {
            return Ok(new
            {
                authService = "Not Found",
                status = "Cannot discover auth-service in Consul",
                timestamp = DateTime.UtcNow
            });
        }

        // Try to call auth-service health endpoint
        using var httpClient = new HttpClient();
        try
        {
            var response = await httpClient.GetAsync($"{url}/health");
            
            return Ok(new
            {
                authService = url,
                status = response.IsSuccessStatusCode ? "Connected" : "Unreachable",
                healthCheck = response.IsSuccessStatusCode ? "Passed" : "Failed",
                httpStatus = (int)response.StatusCode,
                timestamp = DateTime.UtcNow,
                discoveredVia = "Consul Service Discovery"
            });
        }
        catch (Exception ex)
        {
            return Ok(new
            {
                authService = url,
                status = "Error",
                error = ex.Message,
                timestamp = DateTime.UtcNow
            });
        }
    }
}
