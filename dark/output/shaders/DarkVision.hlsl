// phrogg eyes dark.hlsl
// SPDX-License-Identifier: MIT
// Github:      https://github.com/phroggster/ns2_phrogg_eyes
// Workshop ID:	2822011098

#include <renderer/RenderSetup.hlsl>

struct VS_INPUT
{
	float3 ssPosition  : POSITION;
	float2 texCoord    : TEXCOORD0;
	float4 color       : COLOR0;
};

struct VS_OUTPUT
{
	float2 texCoord    : TEXCOORD0;
	float4 color       : COLOR0;
	float4 ssPosition  : SV_POSITION;
};

struct PS_INPUT
{
	float2 texCoord    : TEXCOORD0;
	float4 color       : COLOR0;
};

sampler2D baseTexture;
sampler2D depthTexture;
sampler2D normalTexture;

cbuffer LayerConstants
{
	float startTime;
	float amount;
};

/**
* Vertex shader.
*/
VS_OUTPUT SFXBasicVS(VS_INPUT input)
{
	VS_OUTPUT output;

	output.ssPosition = float4(input.ssPosition, 1);
	output.texCoord = input.texCoord + texelCenter;
	output.color = input.color;

	return output;
}

float4 clamp_tex2D(sampler2D tex, float2 coord)
{
	const float zero = 0.000001;
	const float one  = 0.999999;

	return tex2D(tex, clamp(coord, float2(zero, zero), float2(one, one)));
}

float relative_luminance(float4 color)
{
	return clamp((color.r * 0.2126) + (color.g * 0.7152) + (color.b * 0.0722), 0, 1);
}

float4 SFXDarkVisionPS(PS_INPUT input) : COLOR0
{
	const float entColorStrength = 0.625; // 0: vanilla plus edging; 1: excessive saturation.
	const float staticBrightness = 0.025; // 0: total black; 1: grayscale default luminance.
	const float4 colorMarine = float4(0.75, 0,    0.625, 1.0);
	const float4 colorMarBld = float4(0,    0.25, 1,     1.0);
	const float4 colorGorgie = float4(0.7,  0.35, 0,     1.0);
	const float4 colorAliens = float4(0.6,  1,    0,     1.0);
	const float4 colorEntity = float4(0,    0.15, 0.025, 1.0);
	const float4 colorOthers = float4(0.27, 0,    0.797, 1.0);

	float2 texCoord = input.texCoord;
	float4 inputPixel = tex2D(baseTexture, texCoord);
	if (amount == 0)
	{
		return inputPixel;
	}

	float4 depthdata = tex2D(depthTexture, texCoord);
	float enttype = depthdata.g;
	float depthC = depthdata.r;
	float edge =
		abs(clamp_tex2D(depthTexture, (texCoord + rcpFrame * float2(+1, 0))).r - depthC) +
		abs(clamp_tex2D(depthTexture, (texCoord + rcpFrame * float2(-1, 0))).r - depthC) +
		abs(clamp_tex2D(depthTexture, (texCoord + rcpFrame * float2(0, +1))).r - depthC) +
		abs(clamp_tex2D(depthTexture, (texCoord + rcpFrame * float2(0, -1))).r - depthC);

	if (enttype > 0.99) // marine
	{
		return lerp(inputPixel, colorMarine, entColorStrength) + (edge * colorMarine);
	}
	if (enttype > 0.97) // marine structure
	{
		return lerp(inputPixel, colorMarBld, entColorStrength) + (edge * colorMarBld);
	}
	if (enttype > 0.95) // alien, with transition
	{
		return lerp(inputPixel, colorAliens, amount * entColorStrength) + (edge * colorAliens);
	}
	if (enttype > 0.93) // gorge, with transition
	{
		return lerp(inputPixel, colorGorgie, amount * entColorStrength) + (edge * colorGorgie);
	}
	if (enttype > 0.89) // alien structure, with transition
	{
		return lerp(inputPixel, colorEntity, amount * entColorStrength) + (edge * colorEntity);
	}
	if (enttype > 0.5) // other scene entities and ready room
	{
		return lerp(inputPixel, colorOthers, amount * entColorStrength * 0.5) + (edge * colorOthers);
	}

	// world geometry, viewmodel, etc.
	float softSkybox = pow(edge * 0.9, 2.3) * step(depthC, 100);
	float softenEdge = min(pow(softSkybox * 0.1, 3), 0.001);
	float darkmode = lerp(0, relative_luminance(inputPixel), amount * staticBrightness);

	if (softenEdge > 0)
	{
		return darkmode + softenEdge;
	}
	return darkmode;
}
