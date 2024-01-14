#include "mresource.h"

//#define PRINT_DEBUG

#include <godot_cpp/variant/utility_functions.hpp>

#include "mimage.h"


MResource::QuadTreeRF::QuadTreeRF(MPixelRegion _px_region,float* _data,uint32_t _window_width, float _accuracy, MResource::QuadTreeRF* _root,uint8_t _depth,uint8_t _h_encoding)
:data(_data),window_width(_window_width),px_region(_px_region),accuracy(_accuracy),root(_root),depth(_depth),h_encoding(_h_encoding)
{
    update_min_max_height();
    if(!root){
        // Then we are root
        // And we should calculate how is the h_encoding
        double dh = max_height - min_height;
        if((dh/U4_MAX) <= accuracy){
            h_encoding = H_ENCODE_U4;
        } else if((dh/U8_MAX) <= accuracy) {
            h_encoding = H_ENCODE_U8;
        } else if((dh/U16_MAX) <= accuracy) {
            h_encoding = H_ENCODE_U16;
        } else {
            h_encoding = H_ENCODE_FLOAT;
        }
    }
}

MResource::QuadTreeRF::QuadTreeRF(MPixelRegion _px_region,float* _data,uint32_t _window_width,uint8_t _h_encoding,uint8_t _depth,MResource::QuadTreeRF* _root)
:px_region(_px_region),data(_data),window_width(_window_width),h_encoding(_h_encoding),depth(_depth),root(_root)
{

}

MResource::QuadTreeRF::~QuadTreeRF(){
    if(ne){
        memdelete(ne);
    }
    if(nw){
        memdelete(nw);
    }
    if(se){
        memdelete(se);
    }
    if(sw){
        memdelete(sw);
    }
}

void MResource::QuadTreeRF::update_min_max_height(){
    for(uint32_t y=px_region.top;y<=px_region.bottom;y++){
        for(uint32_t x=px_region.left;x<=px_region.right;x++){
            uint32_t px_index = x + (y*window_width);
            float val = data[px_index];
            if(std::isnan(val)){
                has_hole = true;
                continue;
            }
            if(val>max_height){
                max_height = val;
            }
            if(val<min_height){
                min_height = val;
            }
        }
    }
}

void MResource::QuadTreeRF::divide_upto_leaf(){
    if(px_region.right - px_region.left + 1 <= MIN_BLOCK_SIZE_IN_QUADTREERF){
        return; // we reach the leaf
    }
    uint32_t bw = (px_region.right - px_region.left)/2; //Branch width minus one
    ERR_FAIL_COND(bw==0);
    MPixelRegion px_ne(px_region.left , px_region.left+bw , px_region.top , px_region.top+bw); // North West
    MPixelRegion px_nw(px_region.left+bw+1, px_region.right, px_region.top, px_region.top+bw); // North East
    MPixelRegion px_se(px_region.left, px_region.left+bw, px_region.top+bw+1 , px_region.bottom); // South West
    MPixelRegion px_sw(px_region.left+bw+1, px_region.right, px_region.top+bw+1 , px_region.bottom); // South East
    MResource::QuadTreeRF* who_is_root = root ? root : this;
    uint8_t new_depth = depth+1;
    ne = memnew(MResource::QuadTreeRF(px_ne,data,window_width,accuracy,who_is_root,new_depth,h_encoding));
    nw = memnew(MResource::QuadTreeRF(px_nw,data,window_width,accuracy,who_is_root,new_depth,h_encoding));
    se = memnew(MResource::QuadTreeRF(px_se,data,window_width,accuracy,who_is_root,new_depth,h_encoding));
    sw = memnew(MResource::QuadTreeRF(px_sw,data,window_width,accuracy,who_is_root,new_depth,h_encoding));

    ne->divide_upto_leaf();
    nw->divide_upto_leaf();
    se->divide_upto_leaf();
    sw->divide_upto_leaf();
}

uint32_t MResource::QuadTreeRF::get_flat_head_size(){
    uint32_t size = 1; // one for block specifcation
    // Size for min and max height
    if(h_encoding==H_ENCODE_U4){
        size += 1;
    } else if(h_encoding==H_ENCODE_U8){
        size += 1;
    } else if(h_encoding==H_ENCODE_U16){
        size += 2;
    } else if(h_encoding==H_ENCODE_FLOAT){
        size +=4;
    } else {
        ERR_FAIL_V_MSG(size,"Unknown H Encoidng "+itos(h_encoding));
    }
    return size;
}

uint32_t MResource::QuadTreeRF::get_block_head_size(){
    uint32_t size = 1; // one for block specifcation
    // Size for min and max height
    if(h_encoding==H_ENCODE_U4){
        size += 1;
    } else if(h_encoding==H_ENCODE_U8){
        size += 2;
    } else if(h_encoding==H_ENCODE_U16){
        size += 4;
    } else if(h_encoding==H_ENCODE_FLOAT){
        size +=8;
    } else {
        ERR_FAIL_V_MSG(size,"Unknown H Encoidng "+itos(h_encoding));
    }
    return size;
}

uint32_t MResource::QuadTreeRF::get_optimal_non_divide_size(){
    double dh = max_height - min_height;
    if(dh<accuracy){ // Flat Mode
        data_encoding = DATA_ENCODE_FLAT;
        // Size will remain the same as there is no data block here
        return get_flat_head_size();
    }
    uint32_t size = get_block_head_size();
    uint32_t px_amount = px_region.get_pixel_amount();
    double h_step;
    if(px_amount % 4 == 0){
        h_step = has_hole ? dh/HU2_MAX : dh/U2_MAX;
        if(h_step <= accuracy){
            data_encoding = DATA_ENCODE_U2;
            size += px_amount/4;
            return size;
        }
    }
    if(px_amount % 2 == 0){
        h_step = has_hole ? dh/HU4_MAX : dh/U4_MAX;
        if(h_step <= accuracy){
            data_encoding = DATA_ENCODE_U4;
            size += px_amount/2;
            return size;
        }
    }
    h_step = has_hole ? dh/HU8_MAX : dh/U8_MAX;
    if(h_step <= accuracy){
        data_encoding = DATA_ENCODE_U8;
        size += px_amount;
        return size;
    }
    h_step = has_hole ? dh/HU16_MAX : dh/U16_MAX;
    if(h_step <= accuracy){
        data_encoding = DATA_ENCODE_U16;
        size += px_amount*2;
        return size;
    }
    data_encoding = DATA_ENCODE_FLOAT;
    size = 1; // We don't have a min and max height only one byte for block specification
    size += px_amount*4;
    return size;
}

uint32_t MResource::QuadTreeRF::get_optimal_size(){
    uint32_t size = get_optimal_non_divide_size();
    uint32_t divid_size;
    if(nw){
        divid_size = ne->get_optimal_size();
        divid_size += nw->get_optimal_size();
        divid_size += se->get_optimal_size();
        divid_size += sw->get_optimal_size();
        if(divid_size < size){
            //Then we should divide as division get a better compression
            //Also in this case we Keep the children
            return divid_size;
        }
    }
    //So we should not divde and we should remove children
    if(nw){
        memdelete(ne);
        memdelete(nw);
        memdelete(se);
        memdelete(sw);
        ne = nullptr;
        nw = nullptr;
        se = nullptr;
        sw = nullptr;
    }
    return size;
}

void MResource::QuadTreeRF::encode_min_max_height(PackedByteArray& save_data,uint32_t& save_index){
    ERR_FAIL_COND(data_encoding>=DATA_ENCODE_MAX);
    if(data_encoding==DATA_ENCODE_FLOAT){
        return;
    }
    double main_min_height = root ? root->min_height : min_height;
    double dh_main = root ? root->max_height - root->min_height : max_height - min_height;
    if(h_encoding == H_ENCODE_U4){
        uint8_t minh_u4=0;
        uint8_t maxh_u4=0;
        if(dh_main>0.0000001){ // We should handle dh_main zero only here as that will not happen to othe H_ENCODING
            double h_step_main = dh_main/U4_MAX;
            float fmin = (min_height-main_min_height) / h_step_main;
            float fmax = (max_height-main_min_height) / h_step_main;
            minh_u4 = (uint8_t)std::min(fmin,(float)U4_MAX);
            maxh_u4 = (uint8_t)std::min(fmax,(float)U4_MAX);
        }
        encode_uint4(minh_u4,maxh_u4,save_data.ptrw()+save_index);
        // In this case only min height does not change anything as we store in one byte
        save_index++;
        return;
    }
    if(h_encoding == H_ENCODE_U8){
        double h_step_main = dh_main/U8_MAX;
        float fmin = (min_height-main_min_height) / h_step_main;
        float fmax = (max_height-main_min_height) / h_step_main;
        uint8_t minh_u8 = (uint8_t)std::min(fmin,(float)U8_MAX);
        uint8_t maxh_u8 = (uint8_t)std::min(fmax,(float)U8_MAX);
        save_data[save_index] = minh_u8;
        save_index++;
        if(data_encoding!=DATA_ENCODE_FLAT){
            save_data[save_index] = maxh_u8;
            save_index++;
        }
        return;
    }
    if(h_encoding == H_ENCODE_U16){
        double h_step_main = dh_main/U16_MAX;
        float fmin = (min_height-main_min_height) / h_step_main;
        float fmax = (max_height-main_min_height) / h_step_main;
        uint16_t minh_u16 = (uint16_t)std::min(fmin,(float)U16_MAX);
        uint16_t maxh_u16 = (uint16_t)std::min(fmax,(float)U16_MAX);
        encode_uint16(minh_u16,save_data.ptrw()+save_index);
        save_index+=2;
        if(data_encoding!=DATA_ENCODE_FLAT){
            encode_uint16(maxh_u16,save_data.ptrw()+save_index);
            save_index+=2;
        }
        return;
    }
    if(h_encoding == H_ENCODE_FLOAT){
        encode_float(min_height,save_data.ptrw()+save_index);
        save_index+=4;
        if(data_encoding!=DATA_ENCODE_FLAT){
            encode_float(max_height,save_data.ptrw()+save_index);
            save_index+=4;
        }
        return;
    }
    ERR_FAIL_MSG("H Encoding is not valid "+itos(h_encoding));
}

void MResource::QuadTreeRF::decode_min_max_height(const PackedByteArray& compress_data,uint32_t& decompress_index){
    ERR_FAIL_COND(data_encoding>=DATA_ENCODE_MAX);
    if(data_encoding==DATA_ENCODE_FLOAT){
        return;
    }
    double main_min_height = root ? root->min_height : min_height;
    double dh_main = root ? root->max_height - root->min_height : max_height - min_height;
    if(dh_main<0.00001){
        min_height = main_min_height;
        max_height = main_min_height;
        decompress_index++; //We have H_ENCODE_U4 in this case so one increase
        ERR_FAIL_COND(h_encoding!=H_ENCODE_U4);
        return;
    }
    if(h_encoding == H_ENCODE_U4){
        double h_step_main = dh_main/U4_MAX;
        uint8_t minh_u4=0;
        uint8_t maxh_u4=0;
        decode_uint4(minh_u4,maxh_u4,compress_data.ptr()+decompress_index);
        decompress_index++;
        min_height = main_min_height + (minh_u4*h_step_main);
        max_height = main_min_height + (maxh_u4*h_step_main);
        return;
    }
    if(h_encoding == H_ENCODE_U8){
        double h_step_main = dh_main/U8_MAX;
        uint8_t minh_u8 = compress_data[decompress_index];
        decompress_index++;
        min_height = main_min_height + (minh_u8*h_step_main);
        if(data_encoding==DATA_ENCODE_FLAT){
            max_height = min_height;
            return;
        }
        uint8_t maxh_u8 = compress_data[decompress_index];
        decompress_index++;
        max_height = main_min_height + (maxh_u8*h_step_main);
        return;
    }
    if(h_encoding == H_ENCODE_U16){
        double h_step_main = dh_main/U16_MAX;
        uint16_t minh_u16 = decode_uint16(compress_data.ptr()+decompress_index);
        decompress_index+=2;
        min_height = main_min_height + (minh_u16*h_step_main);
        if(data_encoding==DATA_ENCODE_FLAT){
            max_height = min_height;
            return;
        }
        uint16_t maxh_u16 = decode_uint16(compress_data.ptr()+decompress_index);
        decompress_index+=2;
        max_height = main_min_height + (maxh_u16*h_step_main);
        return;
    }
    if(h_encoding == H_ENCODE_FLOAT){
        min_height = decode_float(compress_data.ptr()+decompress_index);
        decompress_index+=4;
        if(data_encoding==DATA_ENCODE_FLAT){
            max_height = min_height;
            return;
        }
        max_height = decode_float(compress_data.ptr()+decompress_index);
        decompress_index+=4;
        return;
    }
    ERR_FAIL_MSG("Unknow H encoding in uncompress "+itos(h_encoding));
}

void MResource::QuadTreeRF::save_quad_tree_data(PackedByteArray& save_data,uint32_t& save_index){
    ERR_FAIL_COND(accuracy<0);
    if(nw){ // Then this is divided
        // Order of getting info matter
        ne->save_quad_tree_data(save_data,save_index);
        nw->save_quad_tree_data(save_data,save_index);
        se->save_quad_tree_data(save_data,save_index);
        sw->save_quad_tree_data(save_data,save_index);
        return;
    }
    // Creating Headers
    // meta-data
    uint8_t meta = 0;
    meta |= (depth << 4);
    meta |= (uint8_t)has_hole;
    meta |= (data_encoding<<1);
    save_data[save_index] = meta;
    save_index++;
    encode_min_max_height(save_data,save_index);
    if(data_encoding == DATA_ENCODE_FLOAT){
        encode_data_float(save_data,save_index);
        return;
    }
    if(data_encoding == DATA_ENCODE_FLAT){
        return;
    }
    // Otherwise on all condition the min and max height should be encoded
    double dh = max_height - min_height;
    if(data_encoding == DATA_ENCODE_U2){
        encode_data_u2(save_data,save_index);
        return;
    }
    if(data_encoding == DATA_ENCODE_U4){
        encode_data_u4(save_data,save_index);
        return;
    }
    if(data_encoding == DATA_ENCODE_U8){
        encode_data_u8(save_data,save_index);
        return;
    }
    if(data_encoding == DATA_ENCODE_U16){
        encode_data_u16(save_data,save_index);
        return;
    }
    ERR_FAIL_MSG("Unknow Data Encoding "+itos(data_encoding));
}

void MResource::QuadTreeRF::load_quad_tree_data(const PackedByteArray& compress_data,uint32_t& decompress_index){
    uint8_t meta = compress_data[decompress_index];
    uint8_t cdepth = meta >> 4;
    data_encoding = (meta & 0xE) >> 1;
    if(cdepth==depth){
        decompress_index++;
        data_encoding = (meta & 0xE) >> 1;
        has_hole = meta & 0x1;
        decode_min_max_height(compress_data,decompress_index);
        if(data_encoding==DATA_ENCODE_FLAT){
            decode_data_flat(compress_data,decompress_index);
            return;
        }
        if(data_encoding==DATA_ENCODE_U2){
            decode_data_u2(compress_data,decompress_index);
            return;
        }
        if(data_encoding==DATA_ENCODE_U4){
            decode_data_u4(compress_data,decompress_index);
            return;
        }
        if(data_encoding==DATA_ENCODE_U8){
            decode_data_u8(compress_data,decompress_index);
            return;
        }
        if(data_encoding==DATA_ENCODE_U16){
            decode_data_u16(compress_data,decompress_index);
            return;
        }
        if(data_encoding==DATA_ENCODE_FLOAT){
            decode_data_float(compress_data,decompress_index);
            return;
        }
        ERR_FAIL_MSG("Not a valid data encoding "+itos(data_encoding));
        return;
    }
    uint32_t bw = (px_region.right - px_region.left)/2; //Branch width minus one
    ERR_FAIL_COND(bw==0);
    MPixelRegion px_ne(px_region.left , px_region.left+bw , px_region.top , px_region.top+bw); // North West
    MPixelRegion px_nw(px_region.left+bw+1, px_region.right, px_region.top, px_region.top+bw); // North East
    MPixelRegion px_se(px_region.left, px_region.left+bw, px_region.top+bw+1 , px_region.bottom); // South West
    MPixelRegion px_sw(px_region.left+bw+1, px_region.right, px_region.top+bw+1 , px_region.bottom); // South East
    MResource::QuadTreeRF* who_is_root = root ? root : this;
    uint8_t new_depth = depth + 1;
    ne = memnew(MResource::QuadTreeRF(px_ne,data,window_width,h_encoding,new_depth,who_is_root));
    nw = memnew(MResource::QuadTreeRF(px_nw,data,window_width,h_encoding,new_depth,who_is_root));
    se = memnew(MResource::QuadTreeRF(px_se,data,window_width,h_encoding,new_depth,who_is_root));
    sw = memnew(MResource::QuadTreeRF(px_sw,data,window_width,h_encoding,new_depth,who_is_root));
    // Calling order matter
    ne->load_quad_tree_data(compress_data,decompress_index);
    nw->load_quad_tree_data(compress_data,decompress_index);
    se->load_quad_tree_data(compress_data,decompress_index);
    sw->load_quad_tree_data(compress_data,decompress_index);
}

void MResource::QuadTreeRF::encode_data_u2(PackedByteArray& save_data,uint32_t& save_index){
    #ifdef PRINT_DEBUG
    UtilityFunctions::print("EncodeU2 L ",px_region.left," R ",px_region.right," T ",px_region.top, " B ",px_region.bottom, " save_index ",save_index, " ----- ");
    #endif
    double dh = max_height - min_height;
    double h_step = has_hole ? dh/HU2_MAX : dh/U2_MAX;
    uint8_t vals[4];
    uint8_t val_index =0;
    for(uint32_t y=px_region.top;y<=px_region.bottom;y++){
        for(uint32_t x=px_region.left;x<=px_region.right;x++){
            uint32_t px_index = x + (y*window_width);
            double val = data[px_index] - min_height;
            vals[val_index] = std::isnan(val) ? U2_MAX : (uint8_t)(val/h_step);
            vals[val_index] = std::min(vals[val_index],(uint8_t)U2_MAX);
            val_index++;
            if(val_index==4){
                val_index=0;
                //UtilityFunctions::print("Encoding2 ",vals[0]," , ",vals[1]," , ",vals[2]," , ",vals[3]);
                encode_uint2(vals[0],vals[1],vals[2],vals[3],save_data.ptrw()+save_index);
                save_index++;
            }
        }
    }
}

void MResource::QuadTreeRF::encode_data_u4(PackedByteArray& save_data,uint32_t& save_index){
    #ifdef PRINT_DEBUG
    UtilityFunctions::print("EncodeU4 L ",px_region.left," R ",px_region.right," T ",px_region.top, " B ",px_region.bottom, " save_index ",save_index, " ----- ");
    #endif
    double dh = max_height - min_height;
    double h_step = has_hole ? dh/HU4_MAX : dh/U4_MAX;
    //UtilityFunctions::print("Encode4 h step ",h_step, " dh ",dh);
    uint8_t vals[2];
    uint8_t val_index =0;
    for(uint32_t y=px_region.top;y<=px_region.bottom;y++){
        for(uint32_t x=px_region.left;x<=px_region.right;x++){
            uint32_t px_index = x + (y*window_width);
            double val = data[px_index] - min_height;
            vals[val_index] = std::isnan(val) ? U4_MAX :(uint8_t)(val / h_step);
            vals[val_index] = std::min(vals[val_index],(uint8_t)U4_MAX);
            //UtilityFunctions::print("Encode4 ",data[px_index]," -> ",vals[val_index]);
            val_index++;
            if(val_index==2){
                val_index=0;
                encode_uint4(vals[0],vals[1],save_data.ptrw()+save_index);
                save_index++;
                val_index = 0;
            }
        }
    }
}

void MResource::QuadTreeRF::encode_data_u8(PackedByteArray& save_data,uint32_t& save_index){
    #ifdef PRINT_DEBUG
    UtilityFunctions::print("EncodeU8 L ",px_region.left," R ",px_region.right," T ",px_region.top, " B ",px_region.bottom, " save_index ",save_index, " ----- ");
    #endif
    double dh = max_height - min_height;
    double h_step = has_hole ? dh/HU8_MAX : dh/U8_MAX;
    for(uint32_t y=px_region.top;y<=px_region.bottom;y++){
        for(uint32_t x=px_region.left;x<=px_region.right;x++){
            uint32_t px_index = x + (y*window_width);
            double val = data[px_index] - min_height;
            uint8_t sval = std::isnan(val) ? UINT8_MAX : val/h_step;
            sval = std::min(sval,(uint8_t)U8_MAX);
            //UtilityFunctions::print("Encode8 ",val," -> ",sval);
            save_data[save_index] = sval;
            save_index++;
        }
    }
}

void MResource::QuadTreeRF::encode_data_u16(PackedByteArray& save_data,uint32_t& save_index){
    #ifdef PRINT_DEBUG
    UtilityFunctions::print("EncodeU16 L ",px_region.left," R ",px_region.right," T ",px_region.top, " B ",px_region.bottom, " save_index ",save_index, " ----- ");
    #endif
    double dh = max_height - min_height;
    double h_step = has_hole ? dh/HU16_MAX : dh/U16_MAX;
    for(uint32_t y=px_region.top;y<=px_region.bottom;y++){
        for(uint32_t x=px_region.left;x<=px_region.right;x++){
            uint32_t px_index = x + (y*window_width);
            double val = data[px_index] - min_height;
            uint16_t sval = std::isnan(val) ? UINT16_MAX : val/h_step;
            sval = std::min(sval,(uint16_t)U16_MAX);
            //UtilityFunctions::print("Encode16 ",val," -> ",sval);
            encode_uint16(sval,save_data.ptrw()+save_index);
            save_index += 2;
        }
    }
}

void MResource::QuadTreeRF::encode_data_float(PackedByteArray& save_data,uint32_t& save_index){
    #ifdef PRINT_DEBUG
    UtilityFunctions::print("EncodeFloat L ",px_region.left," R ",px_region.right," T ",px_region.top, " B ",px_region.bottom, " save_index ",save_index, " ----- ");
    #endif
    for(uint32_t y=px_region.top;y<=px_region.bottom;y++){
        for(uint32_t x=px_region.left;x<=px_region.right;x++){
            uint32_t px_index = x + (y*window_width);
            float val = data[px_index];
            encode_float(val,save_data.ptrw()+save_index);
            save_index += 4;
        }
    }
}


void MResource::QuadTreeRF::decode_data_flat(const PackedByteArray& compress_data,uint32_t& decompress_index){
    #ifdef PRINT_DEBUG
    UtilityFunctions::print("DecodeFlat L ",px_region.left," R ",px_region.right," T ",px_region.top, " B ",px_region.bottom, " save_index ",decompress_index, " ----- ");
    #endif
    for(uint32_t y=px_region.top;y<=px_region.bottom;y++){
        for(uint32_t x=px_region.left;x<=px_region.right;x++){
            uint32_t px_index = x + (y*window_width);
            data[px_index] = min_height;
        }
    }
}
void MResource::QuadTreeRF::decode_data_u2(const PackedByteArray& compress_data,uint32_t& decompress_index){
    #ifdef PRINT_DEBUG
    UtilityFunctions::print("DecodeU2 L ",px_region.left," R ",px_region.right," T ",px_region.top, " B ",px_region.bottom, " decompress_index ",decompress_index, " ----- ");
    #endif
    float dh = max_height - min_height;
    double h_step = has_hole ? dh/HU2_MAX : dh/U2_MAX;
    uint8_t vals[4];
    uint8_t vals_index=0;
    for(uint32_t y=px_region.top;y<=px_region.bottom;y++){
        for(uint32_t x=px_region.left;x<=px_region.right;x++){
            if(vals_index==0){
                decode_uint2(vals[0],vals[1],vals[2],vals[3],compress_data.ptr()+decompress_index);
                decompress_index++;
            }
            uint32_t px_index = x + (y*window_width);
            data[px_index] = min_height + vals[vals_index]*h_step;
            vals_index++;
            if(vals_index==4){
                vals_index=0;
            }
        }
    }
}
void MResource::QuadTreeRF::decode_data_u4(const PackedByteArray& compress_data,uint32_t& decompress_index){
    #ifdef PRINT_DEBUG
    UtilityFunctions::print("DecodeU4 L ",px_region.left," R ",px_region.right," T ",px_region.top, " B ",px_region.bottom, " decompress_index ",decompress_index, " ----- ");
    #endif
    float dh = max_height - min_height;
    double h_step = has_hole ? dh/HU4_MAX : dh/U4_MAX;
    uint8_t vals[2];
    uint8_t vals_index=0;
    for(uint32_t y=px_region.top;y<=px_region.bottom;y++){
        for(uint32_t x=px_region.left;x<=px_region.right;x++){
            if(vals_index==0){
                decode_uint4(vals[0],vals[1],compress_data.ptr()+decompress_index);
                decompress_index++;
            }
            uint32_t px_index = x + (y*window_width);
            data[px_index] = min_height + vals[vals_index]*h_step;
            vals_index++;
            if(vals_index==2){
                vals_index=0;
            }
        }
    }
    //UtilityFunctions::print("decompress index ",decompress_index);
}
void MResource::QuadTreeRF::decode_data_u8(const PackedByteArray& compress_data,uint32_t& decompress_index){
    #ifdef PRINT_DEBUG
    UtilityFunctions::print("DecodeU8 L ",px_region.left," R ",px_region.right," T ",px_region.top, " B ",px_region.bottom, " decompress_index ",decompress_index, " ----- ");
    #endif
    float dh = max_height - min_height;
    double h_step = has_hole ? dh/HU8_MAX : dh/U8_MAX;
    for(uint32_t y=px_region.top;y<=px_region.bottom;y++){
        for(uint32_t x=px_region.left;x<=px_region.right;x++){
            uint8_t val8 = compress_data[decompress_index];
            decompress_index++;
            uint32_t px_index = x + (y*window_width);
            if(has_hole && val8==U16_MAX){
                data[px_index] = std::numeric_limits<float>::quiet_NaN();
                continue;
            }
            
            data[px_index] = min_height + (float)(val8*h_step);
        }
    }
}
void MResource::QuadTreeRF::decode_data_u16(const PackedByteArray& compress_data,uint32_t& decompress_index){
    #ifdef PRINT_DEBUG
    UtilityFunctions::print("DecodeU16 L ",px_region.left," R ",px_region.right," T ",px_region.top, " B ",px_region.bottom, " decompress_index ",decompress_index, " ----- ");
    #endif
    float dh = max_height - min_height;
    double h_step = has_hole ? dh/HU16_MAX : dh/U16_MAX;
    for(uint32_t y=px_region.top;y<=px_region.bottom;y++){
        for(uint32_t x=px_region.left;x<=px_region.right;x++){
            uint16_t val16 = decode_uint16(compress_data.ptr()+decompress_index);
            decompress_index+=2;
            uint32_t px_index = x + (y*window_width);
            if(has_hole && val16==U16_MAX){
                data[px_index] = std::numeric_limits<float>::quiet_NaN();
                continue;
            }
            data[px_index] = min_height + (float)(val16*h_step);
            //UtilityFunctions::print("decoding16 ",val16, " , ",data[px_index]);
        }
    }
}
void MResource::QuadTreeRF::decode_data_float(const PackedByteArray& compress_data,uint32_t& decompress_index){
    #ifdef PRINT_DEBUG
    UtilityFunctions::print("DecodeFlat L ",px_region.left," R ",px_region.right," T ",px_region.top, " B ",px_region.bottom, " decompress_index ",decompress_index, " ----- ");
    #endif
    for(uint32_t y=px_region.top;y<=px_region.bottom;y++){
        for(uint32_t x=px_region.left;x<=px_region.right;x++){
            uint32_t px_index = x + (y*window_width);
            data[px_index] = decode_float(compress_data.ptr()+decompress_index);
            decompress_index+=4;
        }
    }
}

void MResource::_bind_methods(){
    ClassDB::bind_method(D_METHOD("set_compressed_data","input"), &MResource::set_compressed_data);
    ClassDB::bind_method(D_METHOD("get_compressed_data"), &MResource::get_compressed_data);
    ADD_PROPERTY(PropertyInfo(Variant::DICTIONARY,"compressed_data"), "set_compressed_data","get_compressed_data");

    ClassDB::bind_method(D_METHOD("compress_data","data","name","format","accuracy"), &MResource::insert_data);
    ClassDB::bind_method(D_METHOD("get_data","name"), &MResource::get_data);
}

void MResource::set_compressed_data(const Dictionary& data){
    compressed_data = data;
}
const Dictionary& MResource::get_compressed_data(){
    return compressed_data;
}

void MResource::dump_header(PackedByteArray& compress_data){
    ERR_FAIL_COND(compress_data.size()<MRESOURCE_HEADER_SIZE);
    UtilityFunctions::print("-----Header info-----");
    UtilityFunctions::print("Compress flag ",compress_data[0]);
    UtilityFunctions::print("image format ",compress_data[1]);
    UtilityFunctions::print("Width ",decode_uint16(compress_data.ptrw()+2));
}
void MResource::dump_qtq_header(PackedByteArray& compress_data){
    ERR_FAIL_COND(compress_data.size()<COMPRESSION_QTQ_HEADER_SIZE+MRESOURCE_HEADER_SIZE);
    UtilityFunctions::print("-----Header QTQ info-----");
    UtilityFunctions::print("min ",decode_float(compress_data.ptrw()+4));
    UtilityFunctions::print("max ",decode_float(compress_data.ptrw()+8));
    UtilityFunctions::print("h_encoding ",decode_uint16(compress_data.ptrw()+12));
}

void MResource::insert_data(const PackedByteArray& data, const StringName& name,Image::Format format,float accuracy){
    uint32_t pixel_size = MImage::get_format_pixel_size(format);
    ERR_FAIL_COND_MSG(!pixel_size,"Unsported format");
    ERR_FAIL_COND(data.size() % pixel_size != 0);
    uint32_t pixel_amount = data.size() / pixel_size;
    uint32_t width = sqrt(pixel_amount);
    ERR_FAIL_COND(width<1);
    ERR_FAIL_COND(pixel_amount!=width*width);
    // Originally each image has a power of two plus one size in m terrain
    // But the stored image will always have power of two
    // The edge pixels will be corrected after loading the image
    // Here also we drop the edge pixel if our data have them
    // Also only images with power of two is acceptable for compressing
    PackedByteArray final_data;
    if( ((width - 1) & (width - 2))==0 && width!=2){
        uint32_t new_width = width - 1;
        uint32_t new_size = new_width*new_width*pixel_size;
        final_data.resize(new_size);
        // Copy rows
        uint32_t new_row_size = new_width*pixel_size;
        for(int row=0;row<new_width;row++){
            uint32_t pos_old = row * width * pixel_size;
            uint32_t pos_new = row * new_width * pixel_size;
            memcpy(final_data.ptrw()+pos_new,data.ptr()+pos_old,new_row_size);
        }
        width--;
    } else if (((width & (width - 1)) == 0))
    {
        final_data = data;
    } else {
        ERR_FAIL_MSG("Not a valid image size to compress");
        return;
    }

    PackedByteArray new_compressed_data;
    new_compressed_data.resize(MRESOURCE_HEADER_SIZE);
    //First byte for compression which each compression will add it by itself
    uint8_t compression_flag = 0;
    compression_flag |= COMPRESSION_QTQ;
    new_compressed_data[0] = compression_flag;// 0
    new_compressed_data[1] = (uint8_t)format;// 1
    encode_uint16(width, new_compressed_data.ptrw()+2); // 2,3

    compress_qtq_rf(final_data,new_compressed_data,width,MRESOURCE_HEADER_SIZE,accuracy);
    compressed_data["heightmap"] = new_compressed_data;

}


PackedByteArray MResource::get_data(const StringName& name){
    PackedByteArray out;
    ERR_FAIL_COND_V(!compressed_data.has(name),out);
    PackedByteArray comp_data = compressed_data[name];
    uint8_t compression_flag = comp_data[0];
    uint8_t format = comp_data[1];
    uint16_t width = decode_uint16(comp_data.ptrw()+2);
    uint8_t pixel_size = MImage::get_format_pixel_size((godot::Image::Format)format);
    ERR_FAIL_COND_V(pixel_size==0,out);
    out.resize(width*width*pixel_size);
    decompress_qtq_rf(comp_data,out,width,MRESOURCE_HEADER_SIZE);
    return out;
}

void MResource::compress_qtq_rf(PackedByteArray& uncompress_data,PackedByteArray& compress_data,uint32_t window_width,uint32_t save_index,float accuracy){
    //Building the QuadTree
    MPixelRegion window_px_region(window_width,window_width);
    float* ptr = (float*)uncompress_data.ptrw();
    MResource::QuadTreeRF* quad_tree = memnew(MResource::QuadTreeRF(window_px_region,ptr,window_width,accuracy));
    // Creating compress_QTQ data Header
    {
        compress_data.resize(save_index + COMPRESSION_QTQ_HEADER_SIZE);
        uint8_t* ptrw = compress_data.ptrw();
        ptrw += save_index;
        encode_float(quad_tree->min_height,ptrw);
        ptrw += 4;
        encode_float(quad_tree->max_height,ptrw);
        ptrw += 4;
        ptrw[0] = quad_tree->h_encoding;
        save_index += COMPRESSION_QTQ_HEADER_SIZE;
    }
    quad_tree->divide_upto_leaf();
    uint32_t size = quad_tree->get_optimal_size();
    compress_data.resize(save_index+size);
    uint8_t before_save_index = save_index;
    #ifdef PRINT_DEBUG
    dump_header(compress_data);
    dump_qtq_header(compress_data);
    UtilityFunctions::print("Start to save ----------------------------------------------",save_index);
    #endif
    quad_tree->save_quad_tree_data(compress_data,save_index);
    #ifdef PRINT_DEBUG
    UtilityFunctions::print("End saving ----------------------------------------------",save_index);
    #endif
}

void MResource::decompress_qtq_rf(const PackedByteArray& compress_data,PackedByteArray& uncompress_data,uint32_t window_width,uint32_t decompress_index){
    float main_min_height = decode_float(compress_data.ptr()+decompress_index);
    decompress_index+=4;
    float main_max_height = decode_float(compress_data.ptr()+decompress_index);
    decompress_index+=4;
    uint8_t h_encoding = compress_data[decompress_index];
    decompress_index++;
    MPixelRegion px_region(window_width,window_width);
    //(MPixelRegion _px_region,uint32_t _window_width,uint8_t _h_encoding,uint8_t _depth=0,MResource::QuadTreeRF* _root=nullptr)
    float* ptrw = (float*)uncompress_data.ptrw();
    MResource::QuadTreeRF* quad_tree = memnew(MResource::QuadTreeRF(px_region,ptrw,window_width,h_encoding));
    quad_tree->min_height = main_min_height;
    quad_tree->max_height = main_max_height;
    #ifdef PRINT_DEBUG
    dump_header(compress_data);
    dump_qtq_header(compress_data);
    UtilityFunctions::print("Start to Load ----------------------------------------------",decompress_index);
    #endif
    quad_tree->load_quad_tree_data(compress_data,decompress_index);
    #ifdef PRINT_DEBUG
    UtilityFunctions::print("End Loading ----------------------------------------------",decompress_index);
    #endif
}



void MResource::encode_uint2(uint8_t a,uint8_t b,uint8_t c,uint8_t d, uint8_t *p_arr){
    *p_arr=0;
    *p_arr = a | (b << 2) | (c << 4) | (d << 6);
}

void MResource::decode_uint2(uint8_t& a,uint8_t& b,uint8_t& c,uint8_t& d,const uint8_t *p_arr){
    a = *p_arr & 0x3;
    b = ((*p_arr & 0xC) >> 2);
    c = ((*p_arr & 0x30) >> 4);
    d = ((*p_arr & 0xC0)>>6);
}

void MResource::encode_uint4(uint8_t a,uint8_t b,uint8_t *p_arr){
    *p_arr = a | (b << 4);
}

void MResource::decode_uint4(uint8_t& a,uint8_t& b,const uint8_t *p_arr){
    a = *p_arr & 0xF;
    b = ((*p_arr & 0xF0)>>4);
}

void MResource::encode_uint16(uint16_t p_uint, uint8_t *p_arr){
	for (int i = 0; i < 2; i++) {
		*p_arr = p_uint & 0xFF;
		p_arr++;
		p_uint >>= 8;
	}
}

uint16_t MResource::decode_uint16(const uint8_t *p_arr){
	uint16_t u = 0;
	for (int i = 0; i < 2; i++) {
		uint16_t b = *p_arr;
		b <<= (i * 8);
		u |= b;
		p_arr++;
	}
    return u;
}

void MResource::encode_uint32(uint32_t p_uint, uint8_t *p_arr){
	for (int i = 0; i < 4; i++) {
		*p_arr = p_uint & 0xFF;
		p_arr++;
		p_uint >>= 8;
	}
}

uint32_t MResource::decode_uint32(const uint8_t *p_arr){
	uint32_t u = 0;
	for (int i = 0; i < 4; i++) {
		uint32_t b = *p_arr;
		b <<= (i * 8);
		u |= b;
		p_arr++;
	}
    return u;
}

void MResource::encode_uint64(uint64_t p_uint, uint8_t *p_arr){
	for (int i = 0; i < 8; i++) {
		*p_arr = p_uint & 0xFF;
		p_arr++;
		p_uint >>= 8;
	}
}

uint64_t MResource::decode_uint64(const uint8_t *p_arr){
	uint64_t u = 0;
	for (int i = 0; i < 8; i++) {
		uint64_t b = (*p_arr) & 0xFF;
		b <<= (i * 8);
		u |= b;
		p_arr++;
	}
    return u;
}

void MResource::encode_float(float p_float, uint8_t *p_arr){
    encode_uint32(reinterpret_cast<uint32_t&>(p_float) , p_arr);
}

float MResource::decode_float(const uint8_t *p_arr){
    uint32_t u = decode_uint32(p_arr);
    return reinterpret_cast<float&>(u);
}