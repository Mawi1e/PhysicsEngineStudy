#ifndef NUM_DIR_LIGHTS
    #define NUM_DIR_LIGHTS 3
#endif

#ifndef NUM_POINT_LIGHTS
    #define NUM_POINT_LIGHTS 0
#endif

#ifndef NUM_SPOT_LIGHTS
    #define NUM_SPOT_LIGHTS 0
#endif

#define MaxLights 16

struct Light
{
    float3 Strength;
    float FalloffStart; // ����/������
    float3 Direction;   // ���౤/������
    float FalloffEnd;   // ����/������
    float3 Position;    // ����
    float SpotPower;    // ������
};

struct Material
{
    float4 DiffuseAlbedo; // �л�ݻ���: ���� ������ ����Ҷ� ��� ���� ����ǰ�, ��� ���� �л�Ǿ� ����������, �̶� ���� �л�ݻ�Ǵ� ũ��
    float3 FresnelR0; // �����ڹ����Ŀ��� ����ϴ� �����ٻ翡���� R0: ���������� ������
    float Shininess; // (1 - Roughness)�̸� ��ĥ���� �ݴ�: [0, 1]�̸� 0�� �������� ��ĥ��, 1�� �������� �Ų��ϴ�
};

float CalcAttenuation(float d, float falloffStart, float falloffEnd)
{
    // ���� �����Լ� (falloff End - d / falloffEnd - falloffStart)
    return saturate((falloffEnd - d) / (falloffEnd - falloffStart));
}

// �����ڹ����Ŀ��� ����ϴ� �����ٻ�(Schlick approximation)
float3 SchlickFresnel(float3 R0, float3 normal, float3 lightVec)
{
    // �����ٻ�: R(r) = R(0) x {(1 - R(0)) * (cos(O)^5)}
    // ������Ʈ �ڻ��ι�Ģ: cos(O) = max(L (dot) n, 0)
    // L: lightVec
    // n: normal


    float cosIncidentAngle = saturate(dot(normal, lightVec));

    float f0 = 1.0f - cosIncidentAngle;
    float3 reflectPercent = R0 + (1.0f - R0) * (f0 * f0 * f0 * f0 * f0);

    return reflectPercent;
}

float3 BlinnPhong(float3 lightStrength, float3 lightVec, float3 normal, float3 toEye, Material mat)
{
    const float m = mat.Shininess * 256.0f;
    float3 halfVec = normalize(toEye + lightVec);

    float roughnessFactor = (m + 8.0f) * pow(max(dot(halfVec, normal), 0.0f), m) / 8.0f;
    float3 fresnelFactor = SchlickFresnel(mat.FresnelR0, halfVec, lightVec);

    float3 specAlbedo = fresnelFactor * roughnessFactor;

    // LDR�������� ����Ұ��̱� ������ �ݿ��ݻ����� [0, 1]���̷� ����
    specAlbedo = specAlbedo / (specAlbedo + 1.0f);

    return (mat.DiffuseAlbedo.rgb + specAlbedo) * lightStrength;
}

// ���౤ ���
float3 ComputeDirectionalLight(Light L, Material mat, float3 normal, float3 toEye)
{
    // ���� ���⿡ -1�� ���ϸ� �����Ͱ� �ȴ�
    float3 lightVec = -L.Direction;

    // ������Ʈ �ڻ��ι�Ģ
    float ndotl = max(dot(lightVec, normal), 0.0f);
    float3 lightStrength = L.Strength * ndotl;

    return BlinnPhong(lightStrength, lightVec, normal, toEye, mat);
}

// ���� ���
float3 ComputePointLight(Light L, Material mat, float3 pos, float3 normal, float3 toEye)
{
    // ��x��������� ��ġ�������� ���� ��ġ�������� ���� ����
    float3 lightVec = L.Position - pos;

    // �������� ����
    float d = length(lightVec);

    // �´��� Ȯ��
    if (d > L.FalloffEnd)
        return 0.0f;

    // ������ �Ϲ�ȭ
    lightVec /= d;
    
    // ������Ʈ �ڻ��ι�Ģ
    float ndotl = max(dot(lightVec, normal), 0.0f);
    float3 lightStrength = L.Strength * ndotl;

    // ���Ǽ��⿡ ���������Լ��� ������� ���Ѵ�.
    float att = CalcAttenuation(d, L.FalloffStart, L.FalloffEnd);
    lightStrength *= att;

    return BlinnPhong(lightStrength, lightVec, normal, toEye, mat);
}

// ������ ���
float3 ComputeSpotLight(Light L, Material mat, float3 pos, float3 normal, float3 toEye)
{
    // ��x��������� ��ġ�������� ���� ��ġ�������� ���� ����
    float3 lightVec = L.Position - pos;

    // �������� ����
    float d = length(lightVec);

    // �´��� Ȯ��
    if (d > L.FalloffEnd)
        return 0.0f;

    // ������ �Ϲ�ȭ
    lightVec /= d;

    // ������Ʈ �ڻ��ι�Ģ
    float ndotl = max(dot(lightVec, normal), 0.0f);
    float3 lightStrength = L.Strength * ndotl;

    // ���Ǽ��⿡ ���������Լ��� ������� ���Ѵ�.
    float att = CalcAttenuation(d, L.FalloffStart, L.FalloffEnd);
    lightStrength *= att;

    // ���Ǽ��⿡ max(-L (dot) d, 0)^s: s(L.SpotPower)�� ���������ν� ������������ ũ�⸦ ������ �� �ִ�.
    float spotFactor = pow(max(dot(-lightVec, L.Direction), 0.0f), L.SpotPower);
    lightStrength *= spotFactor;

    return BlinnPhong(lightStrength, lightVec, normal, toEye, mat);
}

float4 ComputeLighting(Light gLights[MaxLights], Material mat,
    float3 pos, float3 normal, float3 toEye,
    float3 shadowFactor)
{
    float3 result = 0.0f;

    int i = 0;

#if (NUM_DIR_LIGHTS > 0)
    for (i = 0; i < NUM_DIR_LIGHTS; ++i)
    {
        result += shadowFactor[i] * ComputeDirectionalLight(gLights[i], mat, normal, toEye);
    }
#endif

#if (NUM_POINT_LIGHTS > 0)
    for (i = NUM_DIR_LIGHTS; i < NUM_DIR_LIGHTS + NUM_POINT_LIGHTS; ++i)
    {
        result += ComputePointLight(gLights[i], mat, pos, normal, toEye);
    }
#endif

#if (NUM_SPOT_LIGHTS > 0)
    for (i = NUM_DIR_LIGHTS + NUM_POINT_LIGHTS; i < NUM_DIR_LIGHTS + NUM_POINT_LIGHTS + NUM_SPOT_LIGHTS; ++i)
    {
        result += ComputeSpotLight(gLights[i], mat, pos, normal, toEye);
    }
#endif 

    return float4(result, 0.0f);
}


Texture2D gTextures : register(t0);

SamplerState gsamPointWrap        : register(s0);
SamplerState gsamPointClamp       : register(s1);
SamplerState gsamLinearWrap       : register(s2);
SamplerState gsamLinearClamp      : register(s3);
SamplerState gsamAnisotropicWrap  : register(s4);
SamplerState gsamAnisotropicClamp : register(s5);

cbuffer cbPerObject : register(b0)
{
    float4x4 gWorld;
    float4x4 gTexTransform;
};

cbuffer cbPass : register(b1)
{
    float4x4 gView;
    float4x4 gInvView;
    float4x4 gProj;
    float4x4 gInvProj;
    float4x4 gViewProj;
    float4x4 gInvViewProj;
    float3 gEyePosW;
    float cbPerObjectPad1;
    float2 gRenderTargetSize;
    float2 gInvRenderTargetSize;
    float gNearZ;
    float gFarZ;
    float gTotalTime;
    float gDeltaTime;
    float4 gAmbientLight;
    float4 gFogColor;
    float gFogStart;
    float gFogRange;
    float2 cbPerObjectPad2;

    Light gLights[MaxLights];
};

cbuffer cbMaterial : register(b2)
{
    float4 gDiffuseAlbedo;
    float3 gFresnelR0;
    float  gRoughness;
    float4x4 gMatTransform;
};
 
struct VertexIn
{
	float3 PosL    : POSITION;
    float3 NormalL : NORMAL;
    float2 TexC : TEXCOORD;
};

struct VertexOut
{
	float4 PosH    : SV_POSITION;
    float3 PosW    : POSITION;
    float3 NormalW : NORMAL;
    float2 TexC : TEXCOORD;
};

VertexOut VS(VertexIn vin)
{
	VertexOut vout = (VertexOut)0.0f;
	
    // ���� ��ķ� ��ȯ
    float4 posW = mul(float4(vin.PosL, 1.0f), gWorld);
    vout.PosW = posW.xyz;

    // if1. ������Ŀ� ��յ��ʰ� �ִٸ�, ����ġ ��������� ����ؾ��Ѵ�.
    // if2. ������Ŀ� ��յ��ʰ� ���ٸ�, ��������� �̿��� ������ ��ȯ�Ѵ�.
    vout.NormalW = mul(vin.NormalL, (float3x3)gWorld);

    // �������ܰ������� ��ȯ
    vout.PosH = mul(posW, gViewProj);

    float4 texTrans = mul(float4(vin.TexC, 0.0f, 1.0f), gTexTransform);
    vout.TexC = mul(texTrans, gMatTransform).xy;

    return vout;
}

float4 toonShading(float4 diffuse) {
    float4 color = saturate(diffuse);
    color = ceil(color * 5) / 5.0f;
    color.a = diffuse.a;

    return color;
}

float4 toonShading_kd(float4 kd) {
    float4 color = saturate(kd);

    if (color.x <= 0.0f) {
        color.x = 0.4f;
    }
    else if (0.0f < color.x && color.x <= 0.5f) {
        color.x = 0.6f;
    }
    else if (0.5f < color.x && color.x <= 1.0f) {
        color.x = 1.0f;
    }

    if (color.y <= 0.0f) {
        color.y = 0.4f;
    }
    else if (0.0f < color.y && color.y <= 0.5f) {
        color.g = 0.6f;
    }
    else if (0.5f < color.y && color.y <= 1.0f) {
        color.y = 1.0f;
    }

    if (color.z <= 0.0f) {
        color.z = 0.4f;
    }
    else if (0.0f < color.z && color.z <= 0.5f) {
        color.z = 0.6f;
    }
    else if (0.5f < color.z && color.z <= 1.0f) {
        color.z = 1.0f;
    }

    color.a = saturate(kd).a;

    return color;
}

float4 toonShading_ks(float4 ks) {
    float4 color = saturate(ks);

    if (0.0f < color.x && color.x <= 0.1f) {
        color.x = 0.0f;
    }
    else if (0.1f < color.x && color.x <= 0.8f) {
        color.x = 0.5f;
    }
    else if (0.8f < color.x && color.x <= 1.0f) {
        color.x = 0.8f;
    }

    if (0.0f < color.y && color.y <= 0.1f) {
        color.y = 0.0f;
    }
    else if (0.1f < color.y && color.y <= 0.8f) {
        color.y = 0.5f;
    }
    else if (0.8f < color.y && color.y <= 1.0f) {
        color.y = 0.8f;
    }

    if (0.0f < color.z && color.z <= 0.1f) {
        color.z = 0.0f;
    }
    else if (0.1f < color.z && color.z <= 0.8f) {
        color.z = 0.5f;
    }
    else if (0.8f < color.z && color.z <= 1.0f) {
        color.z = 0.8f;
    }

    color.a = saturate(ks).a;

    return color;
}

float4 PS(VertexOut pin) : SV_Target
{
    float4 diffuseAlbedo = gTextures.Sample(gsamAnisotropicWrap, pin.TexC) * gDiffuseAlbedo;

#ifdef ALPHA_TEST
    clip(diffuseAlbedo.a - 0.1f);
#endif

    // ������ �����Ͽ�, �������̰� �ƴ� �� �ֱ⶧���� ����ȭ�Ѵ�.
    pin.NormalW = normalize(pin.NormalW);

    // ����Ǵ� ������ �������� ����
    float3 toEyeW = gEyePosW - pin.PosW;
    float distToEye = length(toEyeW);
    toEyeW /= distToEye;
    
	// �ֺ������
    float4 ambient = gAmbientLight * diffuseAlbedo;

    // ���౤���
    const float shininess = 1.0f - gRoughness;
    Material mat = { diffuseAlbedo, gFresnelR0, shininess };
    float3 shadowFactor = 1.0f;
    float4 directLight = ComputeLighting(gLights, mat, pin.PosW,
        pin.NormalW, toEyeW, shadowFactor);

    // directLight = toonShading(directLight);
    // directLight = toonShading_ks(directLight);
    // directLight = toonShading_kd(directLight);

    float4 litColor = ambient + directLight;


#ifdef FOG
    float fogAmount = saturate((distToEye - gFogStart) / gFogRange);
    litColor = lerp(litColor, gFogColor, fogAmount);
#endif


    // �л��������� ���ĸ� �����´�.
    litColor.a = gDiffuseAlbedo.a;

    return litColor;
}


