package com.maclema.mysql
{
    import com.maclema.logging.Logger;
    
    import flash.net.Socket;
    
    /**
     * @private
     **/
    internal class Packet extends Buffer
    {	
        private static const maxAllowedPacket:int = 1024 * 1024 * 1024; //1GB
        public static const maxThreeBytes:int = (256 * 256 * 256) - 1;
        
        private var packetHeader:Buffer;
        private var _packetLength:int = -1;
        private var _packetNumber:int = 0;
        
        private var packetSeq:int = 0;
        
        public var waiting:Boolean = false;
        
        public function Packet(buf:Buffer=null)
        {
            super();
            
            packetHeader = new Buffer();
            
            if ( buf != null )
            {
                //read the packet header...
                buf.readBytes(packetHeader, 0, 4);
                
                packetHeader.position = 0;
                _packetLength = packetHeader.readThreeByteInt();
                _packetNumber = packetHeader.readByte() & 0xFF;
                
                //read the packet data
                buf.readBytes(this, 0, _packetLength);
                
                //move the positions to 0
                this.position = 0;
                packetHeader.position = 0;
            }
        }
        
        public function get packetLength():int
        {
            if ( _packetLength != -1 )
                return _packetLength;
            else
                return this.length;
        }
        
        public function get packetNumber():int
        {
            return _packetNumber;
        }
        
        public function get header():Buffer
        {
            return packetHeader;
        }
        
        public function send(sock:Socket, seqOverride:int=0):int
        {
            if ( packetLength > maxAllowedPacket )
            {
            	Logger.error(this, "Packet Larger Than maxAllowedPacket of " + maxAllowedPacket + " bytes");
            }
            
            if ( seqOverride != 0 ) {
            	this.packetSeq = seqOverride;
            }
            
            if ( packetLength > maxThreeBytes )
            {
                sendSplitPackets(sock);
            }
            else
            {
                sendFullPacket(sock);
            }
            
            return packetSeq;
        }
        
        private function getPacketToSend():Buffer
        {
            var packetToSend:Buffer = new Buffer();
            
            packetHeader.position = 0;
            packetHeader.readBytes(packetToSend, 0, 4);
            
            this.position = 0;
            this.readBytes(packetToSend, 4, this.packetLength);
            
            packetToSend.position = 0;
            
            return packetToSend;
        }
        
        private function sendFullPacket(sock:Socket):void
        {
            packetHeader.position = 0;
            packetHeader.writeThreeByteInt( this.packetLength );
            packetHeader.writeByte( this.packetSeq & 0xFF );
            this.packetSeq++;
            
            sock.writeBytes( getPacketToSend() );
            sock.flush();
        }
        
        private function sendSplitPackets(sock:Socket):void
        {
            var len:int = packetLength;
            var pos:int = 0;
            var seq:int = 0;
            var pack:Packet;
            
            while ( len > maxThreeBytes )
            {
                seq++;
                
                pack = new Packet();
                readBytes(pack, pos, maxThreeBytes);
                pos += maxThreeBytes;
                
                pack.send(sock);
            }
            
            //send last packet
            seq++;
            pack = new Packet();
            readBytes(pack, pos, (len-pos));
            pack.send(sock);
        }
    }
}