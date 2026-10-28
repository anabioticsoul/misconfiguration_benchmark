package com.misconfigbench.ca11;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.oauth2.config.annotation.web.configuration.EnableAuthorizationServer;
import org.springframework.security.oauth2.config.annotation.web.configuration.AuthorizationServerConfigurerAdapter;
import org.springframework.security.oauth2.config.annotation.web.configurers.AuthorizationServerEndpointsConfigurer;
import org.springframework.security.oauth2.config.annotation.web.configurers.AuthorizationServerSecurityConfigurer;
import org.springframework.security.oauth2.config.annotation.configurers.ClientDetailsServiceConfigurer;

@Configuration
@EnableAuthorizationServer
public class AuthorizationServerConfiguration extends AuthorizationServerConfigurerAdapter {
    private final AuthenticationManager authenticationManager;
    private final String clientId;
    private final String clientSecret;

    public AuthorizationServerConfiguration(AuthenticationManager authenticationManager,
                                            @Value("${oauth.client.id}") String clientId,
                                            @Value("${oauth.client.secret}") String clientSecret) {
        this.authenticationManager = authenticationManager;
        this.clientId = clientId;
        this.clientSecret = clientSecret;
    }

    @Override
    public void configure(AuthorizationServerEndpointsConfigurer endpoints) {
        endpoints.authenticationManager(authenticationManager);
    }

    @Override
    public void configure(ClientDetailsServiceConfigurer clients) throws Exception {
        clients.inMemory().withClient(clientId).secret(clientSecret)
                .scopes("read", "write").authorizedGrantTypes("password", "refresh_token")
                .accessTokenValiditySeconds(1800);
    }

    @Override
    public void configure(AuthorizationServerSecurityConfigurer security) {
        security.allowFormAuthenticationForClients();
    }
}
