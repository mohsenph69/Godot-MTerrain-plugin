#ifndef MRESOURCE
#define MRESOURCE

#define MRESOURCE_HEADER_SIZE 4
// COMPRESS DATA HEADER --- in total 4 byte
// uint8_t compressions -> Compressions applied, with each compression type change one bit from zero to one
// The first byte shout never be compressed ass it determine which compression has been applied
// so any compression except COMPRESSION_QTQ will be applied from here like huffman or LZ777
// uint8_t image_format -> same as Image::Format in image class in Godot
// uint16_t width (LE) -> width and height are equale so height is this

#define COMPRESSION_QTQ_HEADER_SIZE 9
// COMPRESSION_QTQ header start from 4th-byte position (As always aplly first)
// float min_height -> 4 byte
// float max_height -> 4 byte
// uint8_t h_encoding -> show how min and max height in each block is encoded
////////// 0 -> encoded as uint4
////////// 1 -> encoded as uint8
////////// 2 -> encoded as uint16
////////// 3 -> encoded as float

// COMPRESSION_QTQ Block start after above
// 0xF0 the most left byte is the depth inside the QuadTreeRF
// 0x0F the remaining 4 right bytes are as Follows
// 1 left byte show if we have a hole inside that block in case there is a hole inside that block the last number uintX will reserve for hole and in case it is float the hole represent NAN value
// 3 right byte of that show the encoding of block which is as follow: (DEFINED BY DATA_ENCODE_)
////////// 0 -> flat and the entire block has the same height and its determine by min height, in this case we don't have max-height, and there is no data in block
////////// 2 -> height are encoded as uint2
////////// 3 -> height are encoded as uint4
////////// 4 -> height are encoded as uint8
////////// 5 -> height are encoded as uint16
////////// 6 -> height are encoded as float -> in this case the is no min and max height in header


// Min and max height in each block divid the main min and max block from zero to maximum number which they can handle

#define DATA_ENCODE_FLAT 0
#define DATA_ENCODE_U2 1
#define DATA_ENCODE_U4 2
#define DATA_ENCODE_U8 3
#define DATA_ENCODE_U16 4
#define DATA_ENCODE_FLOAT 5
#define DATA_ENCODE_MAX 6

// one last number in each encoding is reserved for terrain holes
#define U2_MAX 3
#define U4_MAX 15
#define U8_MAX 255
#define U16_MAX 65535

#define MIN_U4(value) (((value)>U4_MAX) ? U4_MAX : value);

#define HU2_MAX 2
#define HU4_MAX 14
#define HU8_MAX 254
#define HU16_MAX 65534

#define H_ENCODE_U4 0
#define H_ENCODE_U8 1
#define H_ENCODE_U16 2
#define H_ENCODE_FLOAT 3
#define H_ENCODE_MAX 4


#define MIN_BLOCK_SIZE_IN_QUADTREERF 4

// If more compression will be added in future
// All compression must be be lossless except COMPRESSION_QTQ or any comression which is in first order
#define COMPRESSION_QTQ 1 // QuadTreeRF Quantazation compression

#include <godot_cpp/classes/resource.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/classes/image.hpp>
#include "mpixel_region.h"

using namespace godot;

class MResource : public Resource {
    GDCLASS(MResource,Resource);

    protected:
    static void _bind_methods();

    private:
    struct QuadTreeRF
    {
        MResource::QuadTreeRF* ne = nullptr; //North east
        MResource::QuadTreeRF* nw = nullptr; //North west
        MResource::QuadTreeRF* se = nullptr; //South east
        MResource::QuadTreeRF* sw = nullptr; //South west
        bool has_hole = false;
        MPixelRegion px_region;
        float* data=nullptr; // Point always to uncompress data
        uint32_t window_width;
        uint8_t depth = 0;
        uint8_t h_encoding;
        uint8_t data_encoding=255;
        float accuracy=-1;
        float min_height=10000;
        float max_height=-10000;
        QuadTreeRF* root=nullptr;
        QuadTreeRF(MPixelRegion _px_region,float* _data,uint32_t _window_width, float _accuracy, MResource::QuadTreeRF* _root=nullptr,uint8_t _depth=0,uint8_t _h_encoding=255);
        //Bellow constructor is used for decompression
        QuadTreeRF(MPixelRegion _px_region,float* _data,uint32_t _window_width,uint8_t _h_encoding,uint8_t _depth=0,MResource::QuadTreeRF* _root=nullptr);
        ~QuadTreeRF();
        void update_min_max_height();
        void divide_upto_leaf();
        _FORCE_INLINE_ uint32_t get_flat_head_size();
        _FORCE_INLINE_ uint32_t get_block_head_size();
        uint32_t get_optimal_non_divide_size(); // This will also determine data encoding
        //Bellow will call above method so data encoding will be determined
        //Also bellow will determine if we should divide or not
        uint32_t get_optimal_size();
        private:
        void encode_min_max_height(PackedByteArray& save_data,uint32_t& save_index);
        void decode_min_max_height(const PackedByteArray& compress_data,uint32_t& decompress_index);
        public:
        void save_quad_tree_data(PackedByteArray& save_data,uint32_t& save_index);
        void load_quad_tree_data(const PackedByteArray& compress_data,uint32_t& decompress_index);
        
        private:
        void encode_data_u2(PackedByteArray& save_data,uint32_t& save_index);
        void encode_data_u4(PackedByteArray& save_data,uint32_t& save_index);
        void encode_data_u8(PackedByteArray& save_data,uint32_t& save_index);
        void encode_data_u16(PackedByteArray& save_data,uint32_t& save_index);
        void encode_data_float(PackedByteArray& save_data,uint32_t& save_index);

        void decode_data_flat(const PackedByteArray& compress_data,uint32_t& decompress_index);
        void decode_data_u2(const PackedByteArray& compress_data,uint32_t& decompress_index);
        void decode_data_u4(const PackedByteArray& compress_data,uint32_t& decompress_index);
        void decode_data_u8(const PackedByteArray& compress_data,uint32_t& decompress_index);
        void decode_data_u16(const PackedByteArray& compress_data,uint32_t& decompress_index);
        void decode_data_float(const PackedByteArray& compress_data,uint32_t& decompress_index);
    };
    Dictionary compressed_data;

    public:
    void set_compressed_data(const Dictionary& data);
    const Dictionary& get_compressed_data();
    void dump_header(PackedByteArray& compress_data);
    void dump_qtq_header(PackedByteArray& compress_data);

    void insert_data(const PackedByteArray& data, const StringName& name,Image::Format format,float accuracy);
    PackedByteArray get_data(const StringName& name);


    private:
    // Compresion base on 
    void compress_qtq_rf(PackedByteArray& uncompress_data,PackedByteArray& compress_data,uint32_t window_width,uint32_t save_index,float accuracy);
    void decompress_qtq_rf(const PackedByteArray& compress_data,PackedByteArray& uncompress_data,uint32_t window_width,uint32_t decompress_index);

    public:
    // Too much overhead if use these in PackedByteArray
    static _FORCE_INLINE_ void encode_uint2(uint8_t a,uint8_t b,uint8_t c,uint8_t d, uint8_t *p_arr);
    static _FORCE_INLINE_ void decode_uint2(uint8_t& a,uint8_t& b,uint8_t& c,uint8_t& d,const uint8_t *p_arr);
    static _FORCE_INLINE_ void encode_uint4(uint8_t a,uint8_t b, uint8_t *p_arr);
    static _FORCE_INLINE_ void decode_uint4(uint8_t& a,uint8_t& b,const uint8_t *p_arr);
    static _FORCE_INLINE_ void encode_uint16(uint16_t p_uint, uint8_t *p_arr);
    static _FORCE_INLINE_ uint16_t decode_uint16(const uint8_t *p_arr);
    static _FORCE_INLINE_ void encode_uint32(uint32_t p_uint, uint8_t *p_arr);
    static _FORCE_INLINE_ uint32_t decode_uint32(const uint8_t *p_arr);
    static _FORCE_INLINE_ void encode_uint64(uint64_t p_uint, uint8_t *p_arr);
    static _FORCE_INLINE_ uint64_t decode_uint64(const uint8_t *p_arr);
    static _FORCE_INLINE_ void encode_float(float p_float, uint8_t *p_arr);
    static _FORCE_INLINE_ float decode_float(const uint8_t *p_arr);
};
#endif