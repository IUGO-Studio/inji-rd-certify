package io.mosip.certify.utils;

import io.mosip.certify.core.constants.VCFormats;
import io.mosip.certify.core.dto.CredentialConfigurationSupportedDTO;
import io.mosip.certify.core.dto.CredentialDefinition;
import io.mosip.certify.core.dto.CredentialIssuerMetadataVD13DTO;
import io.mosip.certify.core.dto.CredentialRequest;
import io.mosip.certify.core.dto.CredentialMetadata;
import org.junit.Test;

import java.util.List;
import java.util.Map;
import java.util.Optional;

import static org.junit.Assert.*;

public class VCIssuanceUtilTest {

    private static final String CUENTA_DIGITAL_SCOPES = "openid offline_access profile email";

    @Test
    public void scopesMatch_exactCredentialScope() {
        assertTrue(VCIssuanceUtil.scopesMatch("mock_identity_vc_ldp", "mock_identity_vc_ldp"));
    }

    @Test
    public void scopesMatch_tokenPieceInCuentaDigitalList() {
        assertTrue(VCIssuanceUtil.scopesMatch("openid", CUENTA_DIGITAL_SCOPES));
        assertTrue(VCIssuanceUtil.scopesMatch("email", CUENTA_DIGITAL_SCOPES));
        assertTrue(VCIssuanceUtil.scopesMatch("offline_access", CUENTA_DIGITAL_SCOPES));
        assertTrue(VCIssuanceUtil.scopesMatch("profile", CUENTA_DIGITAL_SCOPES));
    }

    @Test
    public void scopesMatch_doesNotSubstringMatch() {
        assertFalse(VCIssuanceUtil.scopesMatch("open", CUENTA_DIGITAL_SCOPES));
        assertFalse(VCIssuanceUtil.scopesMatch("mail", CUENTA_DIGITAL_SCOPES));
    }

    @Test
    public void scopesMatch_fullClaimOnlyEqualsWholeConfiguredString() {
        assertTrue(VCIssuanceUtil.scopesMatch(CUENTA_DIGITAL_SCOPES, CUENTA_DIGITAL_SCOPES));
        assertFalse(VCIssuanceUtil.scopesMatch("email profile openid offline_access", CUENTA_DIGITAL_SCOPES));
        assertFalse(VCIssuanceUtil.scopesMatch("unknown-scope", CUENTA_DIGITAL_SCOPES));
    }

    @Test
    public void getScopeCredentialMapping_cuentaDigitalSplitToken_matchesLdpConfig() {
        CredentialIssuerMetadataVD13DTO metadata = metadataWithScope(CUENTA_DIGITAL_SCOPES);
        CredentialRequest request = ldpRequest();

        Optional<CredentialMetadata> result = VCIssuanceUtil.getScopeCredentialMapping(
                "openid", VCFormats.LDP_VC, metadata, request);

        assertTrue(result.isPresent());
        assertEquals(CUENTA_DIGITAL_SCOPES, result.get().getScope());
        assertEquals("DriverLicense", result.get().getId());
    }

    @Test
    public void getScopeCredentialMapping_unknownTokenScope_empty() {
        CredentialIssuerMetadataVD13DTO metadata = metadataWithScope(CUENTA_DIGITAL_SCOPES);

        Optional<CredentialMetadata> result = VCIssuanceUtil.getScopeCredentialMapping(
                "unknown-scope", VCFormats.LDP_VC, metadata, ldpRequest());

        assertTrue(result.isEmpty());
    }

    private static CredentialIssuerMetadataVD13DTO metadataWithScope(String scope) {
        CredentialDefinition definition = new CredentialDefinition();
        definition.setContext(List.of("https://www.w3.org/2018/credentials/v1"));
        definition.setType(List.of("DriverLicense", "VerifiableCredential"));

        CredentialConfigurationSupportedDTO supported = new CredentialConfigurationSupportedDTO();
        supported.setScope(scope);
        supported.setFormat(VCFormats.LDP_VC);
        supported.setCredentialDefinition(definition);

        CredentialIssuerMetadataVD13DTO metadata = new CredentialIssuerMetadataVD13DTO();
        metadata.setCredentialConfigurationSupportedDTO(Map.of("DriverLicense", supported));
        return metadata;
    }

    private static CredentialRequest ldpRequest() {
        CredentialDefinition definition = new CredentialDefinition();
        definition.setContext(List.of("https://www.w3.org/2018/credentials/v1"));
        definition.setType(List.of("DriverLicense", "VerifiableCredential"));

        CredentialRequest request = new CredentialRequest();
        request.setFormat(VCFormats.LDP_VC);
        request.setCredential_definition(definition);
        return request;
    }
}
